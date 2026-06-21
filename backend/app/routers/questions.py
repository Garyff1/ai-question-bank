from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, field_validator
from sqlalchemy.orm import Session
from datetime import datetime
import json

from app.database import get_db
from app.models import User, Material, QuestionBank, ApiConfig
from app.utils.auth import get_current_user
from app.services.ai_service import generate_questions

router = APIRouter()


class GenerateRequest(BaseModel):
    material_id: int
    question_count: int = 5
    question_type: str = "choice"
    target_audience: str = "通用"

    @field_validator("question_count")
    @classmethod
    def count_range(cls, v: int) -> int:
        if v < 1 or v > 20:
            raise ValueError("题目数量必须在1-20之间")
        return v

    @field_validator("question_type")
    @classmethod
    def type_valid(cls, v: str) -> str:
        VALID = {"choice", "multi_choice", "true_false", "fill", "subjective"}
        types = [t.strip() for t in v.split(",")]
        for t in types:
            if t not in VALID:
                raise ValueError(f"无效的题目类型: {t}")
        return v


class QuestionBankResponse(BaseModel):
    id: int
    material_id: int
    question_type: str
    target_audience: str | None
    question_count: int
    created_at: datetime

    class Config:
        from_attributes = True


@router.post("/generate")
def generate(req: GenerateRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    material = db.query(Material).filter(
        Material.id == req.material_id, Material.user_id == current_user.id
    ).first()
    if not material:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="资料不存在")

    # 读取用户的 API 配置（如果有）
    api_config = db.query(ApiConfig).filter(ApiConfig.user_id == current_user.id).first()
    if not api_config:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="请先在设置页面配置 API Key")

    # 支持混合题型：用逗号分隔，如 "choice,fill"
    types = [t.strip() for t in req.question_type.split(",")]
    all_questions = []
    per_type = max(1, req.question_count // len(types))
    remainder = req.question_count - per_type * len(types)

    try:
        for i, qtype in enumerate(types):
            count = per_type + (1 if i == 0 else 0) * remainder
            questions = generate_questions(
                text=material.content_text[:10000],
                question_type=qtype,
                question_count=count,
                target_audience=req.target_audience,
                api_key=api_config.api_key,
                api_base=api_config.api_base,
                model=api_config.model_name,
            )
            # 标注题型到每道题
            for q in questions:
                q["question_type"] = qtype
            all_questions.extend(questions)
    except RuntimeError as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))

    bank = QuestionBank(
        user_id=current_user.id,
        material_id=req.material_id,
        question_type=req.question_type,
        target_audience=req.target_audience,
        questions_json=json.dumps(all_questions, ensure_ascii=False),
    )
    db.add(bank)
    db.commit()
    db.refresh(bank)

    return {"bank_id": bank.id, "question_count": len(all_questions), "questions": all_questions}


@router.get("/banks", response_model=list[QuestionBankResponse])
def list_banks(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    banks = (
        db.query(QuestionBank)
        .filter(QuestionBank.user_id == current_user.id)
        .order_by(QuestionBank.created_at.desc())
        .all()
    )
    result = []
    for b in banks:
        questions = json.loads(b.questions_json)
        result.append(QuestionBankResponse(
            id=b.id,
            material_id=b.material_id,
            question_type=b.question_type,
            target_audience=b.target_audience,
            question_count=len(questions),
            created_at=b.created_at,
        ))
    return result


@router.get("/banks/{bank_id}")
def get_bank(
    bank_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    bank = db.query(QuestionBank).filter(
        QuestionBank.id == bank_id, QuestionBank.user_id == current_user.id
    ).first()
    if not bank:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="题库不存在")

    questions = json.loads(bank.questions_json)
    sanitized = []
    for q in questions:
        item = {"question": q["question"]}
        if "options" in q:
            item["options"] = q["options"]
        sanitized.append(item)

    return {"id": bank.id, "question_type": bank.question_type, "questions": sanitized,
            "question_count": len(sanitized), "created_at": bank.created_at}


@router.get("/banks/{bank_id}/wrong")
def get_wrong_questions(
    bank_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """获取某次练习的错题详情"""
    bank = db.query(QuestionBank).filter(
        QuestionBank.id == bank_id, QuestionBank.user_id == current_user.id
    ).first()
    if not bank:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="题库不存在")

    from app.models import PracticeHistory
    history = db.query(PracticeHistory).filter(
        PracticeHistory.bank_id == bank_id,
        PracticeHistory.user_id == current_user.id,
    ).order_by(PracticeHistory.completed_at.desc()).first()

    wrong_indices = []
    if history and history.wrong_ids:
        wrong_indices = json.loads(history.wrong_ids)

    questions = json.loads(bank.questions_json)
    wrong_questions = []
    for idx in wrong_indices:
        if 0 <= idx < len(questions):
            q = questions[idx]
            wrong_questions.append({
                "index": idx,
                "question": q.get("question", ""),
                "options": q.get("options", []),
                "answer": q.get("answer", ""),
                "explanation": q.get("explanation", ""),
            })

    return {"bank_id": bank_id, "wrong_questions": wrong_questions}
