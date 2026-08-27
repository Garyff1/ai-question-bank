from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, Field, field_validator
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User
from app.utils.auth import hash_password, verify_password, create_access_token, get_current_user
from app.security.login_limiter import LoginAttemptLimiter

router = APIRouter()
login_limiter = LoginAttemptLimiter()


def _normalize_email(value: str) -> str:
    normalized = value.strip().lower()
    if len(normalized) > 255 or "@" not in normalized:
        raise ValueError("请输入有效邮箱地址")
    local, _, domain = normalized.partition("@")
    if not local or "." not in domain or domain.startswith(".") or domain.endswith("."):
        raise ValueError("请输入有效邮箱地址")
    return normalized


class RegisterRequest(BaseModel):
    email: str
    password: str = Field(min_length=10, max_length=128)

    @field_validator("email")
    @classmethod
    def email_valid(cls, value: str) -> str:
        return _normalize_email(value)


class LoginRequest(BaseModel):
    email: str
    password: str = Field(min_length=1, max_length=128)

    @field_validator("email")
    @classmethod
    def email_valid(cls, value: str) -> str:
        return _normalize_email(value)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    email: str


class UserResponse(BaseModel):
    id: int
    email: str


@router.post("/register", response_model=TokenResponse)
def register(req: RegisterRequest, db: Session = Depends(get_db)):
    # 暂时简化注册：只要不重复即可注册
    existing = db.query(User).filter(User.email == req.email).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="该账号已被注册")

    user = User(email=req.email, password_hash=hash_password(req.password))
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token(user.id)
    return TokenResponse(access_token=token, user_id=user.id, email=user.email)


@router.post("/login", response_model=TokenResponse)
def login(req: LoginRequest, request: Request, db: Session = Depends(get_db)):
    host = request.client.host if request.client else "unknown"
    limit_key = f"{host}:{req.email}"
    if login_limiter.is_blocked(limit_key):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="登录尝试过多，请稍后再试",
        )
    user = db.query(User).filter(User.email == req.email).first()
    if not user or not verify_password(req.password, user.password_hash):
        login_limiter.record_failure(limit_key)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="账号或密码错误")

    login_limiter.clear(limit_key)
    token = create_access_token(user.id)
    return TokenResponse(access_token=token, user_id=user.id, email=user.email)


@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return UserResponse(id=current_user.id, email=current_user.email)
