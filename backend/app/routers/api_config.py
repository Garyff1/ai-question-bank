import json
import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, field_validator
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User, ApiConfig
from app.utils.auth import get_current_user
from app.config import settings

router = APIRouter()

# 预设服务商模板
PROVIDER_TEMPLATES = {
    "deepseek": {"name": "DeepSeek", "api_base": "https://api.deepseek.com/v1", "model": "deepseek-chat"},
    "openai": {"name": "OpenAI", "api_base": "https://api.openai.com/v1", "model": "gpt-3.5-turbo"},
    "siliconflow": {"name": "SiliconFlow", "api_base": "https://api.siliconflow.cn/v1", "model": "Qwen/Qwen2.5-7B-Instruct"},
    "tongyi": {"name": "通义千问", "api_base": "https://dashscope.aliyuncs.com/compatible-mode/v1", "model": "qwen-turbo"},
    "zhipu": {"name": "智谱清言", "api_base": "https://open.bigmodel.cn/api/paas/v4", "model": "glm-4-flash"},
    "custom": {"name": "自定义", "api_base": "", "model": ""},
}


class SaveConfigRequest(BaseModel):
    provider: str = "custom"
    api_key: str
    api_base: str
    model_name: str

    model_config = {"protected_namespaces": ()}

    @field_validator("provider")
    @classmethod
    def provider_valid(cls, v: str) -> str:
        if v not in PROVIDER_TEMPLATES:
            raise ValueError("不支持的服务商")
        return v

    @field_validator("api_key")
    @classmethod
    def key_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("API Key 不能为空")
        return v.strip()

    @field_validator("api_base")
    @classmethod
    def base_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("API 地址不能为空")
        return v.rstrip("/")

    @field_validator("model_name")
    @classmethod
    def model_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("模型名称不能为空")
        return v.strip()


class TestRequest(BaseModel):
    api_key: str
    api_base: str
    model_name: str

    model_config = {"protected_namespaces": ()}


@router.get("/providers")
def get_providers():
    """获取预设服务商列表"""
    return PROVIDER_TEMPLATES


@router.get("/config")
def get_config(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """获取当前用户的 API 配置"""
    config = db.query(ApiConfig).filter(ApiConfig.user_id == current_user.id).first()
    if not config:
        return {"configured": False, "message": "未配置 API，请先添加 API Key"}
    return {
        "configured": True,
        "provider": config.provider,
        "api_base": config.api_base,
        "model_name": config.model_name,
        "created_at": config.created_at,
    }


@router.post("/config")
def save_config(
    req: SaveConfigRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """保存 API 配置（每个用户仅保留一条）"""
    existing = db.query(ApiConfig).filter(ApiConfig.user_id == current_user.id).first()
    if existing:
        existing.provider = req.provider
        existing.api_key = req.api_key
        existing.api_base = req.api_base
        existing.model_name = req.model_name
    else:
        config = ApiConfig(
            user_id=current_user.id,
            provider=req.provider,
            api_key=req.api_key,
            api_base=req.api_base,
            model_name=req.model_name,
        )
        db.add(config)
    db.commit()
    return {"message": "API 配置已保存"}


@router.post("/test")
def test_connection(
    req: TestRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """测试 API 连通性：发送一条简单请求"""
    try:
        headers = {
            "Authorization": f"Bearer {req.api_key}",
            "Content-Type": "application/json",
        }
        payload = {
            "model": req.model_name,
            "messages": [{"role": "user", "content": "请回复 OK 两个字，不要多余内容。"}],
            "max_tokens": 10,
            "temperature": 0.1,
        }
        url = f"{req.api_base.rstrip('/')}/chat/completions"

        with httpx.Client(timeout=30) as client:
            resp = client.post(url, json=payload, headers=headers)
            if resp.status_code == 200:
                data = resp.json()
                reply = data["choices"][0]["message"]["content"]
                return {"success": True, "message": f"连接成功！AI 回复：{reply}"}
            elif resp.status_code == 401:
                return {"success": False, "message": "认证失败：API Key 无效"}
            elif resp.status_code == 404:
                return {"success": False, "message": "接口地址错误，请检查 API Base URL"}
            else:
                return {"success": False, "message": f"连接失败 (HTTP {resp.status_code})：{resp.text[:200]}"}
    except httpx.ConnectError:
        return {"success": False, "message": "无法连接服务器，请检查 API Base URL 是否正确"}
    except httpx.TimeoutException:
        return {"success": False, "message": "连接超时，请检查网络或 API 地址"}
    except Exception as e:
        return {"success": False, "message": f"测试失败：{str(e)[:200]}"}
