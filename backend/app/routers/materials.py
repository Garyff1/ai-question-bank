from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from datetime import datetime

from app.database import get_db
from app.models import User, Material
from app.utils.auth import get_current_user
from app.services.file_service import parse_file
from app.config import settings

router = APIRouter()


class MaterialResponse(BaseModel):
    id: int
    filename: str
    created_at: datetime

    class Config:
        from_attributes = True


@router.post("/upload", response_model=MaterialResponse)
async def upload_material(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    content = await file.read()
    if len(content) > settings.MAX_FILE_SIZE:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="文件大小超过20MB限制")

    filename = file.filename or "unnamed"
    text = parse_file(filename, content)
    if not text or len(text.strip()) < 10:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="无法从文件中提取有效文本内容")

    material = Material(user_id=current_user.id, filename=filename, content_text=text)
    db.add(material)
    db.commit()
    db.refresh(material)
    return MaterialResponse(id=material.id, filename=material.filename, created_at=material.created_at)


@router.get("", response_model=list[MaterialResponse])
def list_materials(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    materials = (
        db.query(Material)
        .filter(Material.user_id == current_user.id)
        .order_by(Material.created_at.desc())
        .all()
    )
    return [MaterialResponse(id=m.id, filename=m.filename, created_at=m.created_at) for m in materials]


@router.delete("/{material_id}")
def delete_material(
    material_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    material = db.query(Material).filter(Material.id == material_id, Material.user_id == current_user.id).first()
    if not material:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="资料不存在")
    db.delete(material)
    db.commit()
    return {"message": "删除成功"}
