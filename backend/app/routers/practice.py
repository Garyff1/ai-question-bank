from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import func
import json
from datetime import datetime

from app.database import get_db
from app.models import User, QuestionBank, Material, PracticeRecord, PracticeHistory
from app.utils.auth import get_current_user

router = APIRouter()


class SubmitRequest(BaseModel):
    bank_id: int
    question_index: int
    user_answer: str


class SubmitResponse(BaseModel):
    is_correct: bool
    correct_answer: str | list[str] | None = None
    explanation: str | None = None


class CompleteRequest(BaseModel):
    bank_id: int
    total_questions: int
    correct_count: int
    wrong_indices: list[int]


class HistoryResponse(BaseModel):
    id: int
    bank_id: int
    total_questions: int
    correct_count: int
    accuracy: float
    wrong_count: int
    completed_at: datetime

    class Config:
        from_attributes = True


@router.post("/submit", response_model=SubmitResponse)
def submit(
    req: SubmitRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    bank = db.query(QuestionBank).filter(
        QuestionBank.id == req.bank_id, QuestionBank.user_id == current_user.id
    ).first()
    if not bank:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="题库不存在")

    questions = json.loads(bank.questions_json)
    if req.question_index < 0 or req.question_index >= len(questions):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="题目索引无效")

    q = questions[req.question_index]
    correct_answer = q.get("answer", "")

    qtype = bank.question_type
    if isinstance(correct_answer, list):
        # 多选题：按字母排序后拼接比较
        correct_set = sorted([str(a).strip().upper() for a in correct_answer])
        user_set = sorted([a.strip().upper() for a in req.user_answer.replace("，", ",").split(",")])
        is_correct = correct_set == user_set
    elif qtype == "true_false":
        # 判断题：宽松匹配
        ua = req.user_answer.strip().lower()
        ca = str(correct_answer).strip().lower()
        is_correct = ua == ca or (ua in ("对", "✔") and ca == "正确") or (ua in ("错", "✘") and ca == "错误")
    elif qtype == "subjective":
        # 主观题：人工批改性质，答即对
        is_correct = True
    else:
        is_correct = req.user_answer.strip().lower() == str(correct_answer).strip().lower()

    record = PracticeRecord(
        user_id=current_user.id,
        question_bank_id=req.bank_id,
        question_index=req.question_index,
        user_answer=req.user_answer,
        is_correct=is_correct,
    )
    db.add(record)
    db.commit()

    return SubmitResponse(
        is_correct=is_correct,
        correct_answer=correct_answer,
        explanation=q.get("explanation", ""),
    )


@router.post("/complete")
def complete_practice(
    req: CompleteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    history = PracticeHistory(
        user_id=current_user.id,
        bank_id=req.bank_id,
        total_questions=req.total_questions,
        correct_count=req.correct_count,
        wrong_ids=json.dumps(req.wrong_indices, ensure_ascii=False),
    )
    db.add(history)
    db.commit()
    db.refresh(history)
    return {"history_id": history.id, "message": "练习记录已保存"}


@router.get("/history")
def get_history(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    histories = (
        db.query(PracticeHistory)
        .filter(PracticeHistory.user_id == current_user.id)
        .order_by(PracticeHistory.completed_at.desc())
        .all()
    )

    # 预先统计每个 bank 的练习序号
    bank_counts = {}
    from sqlalchemy import case
    all_histories = (
        db.query(PracticeHistory)
        .filter(PracticeHistory.user_id == current_user.id)
        .order_by(PracticeHistory.completed_at.asc())
        .all()
    )
    for h in all_histories:
        bank_counts[h.bank_id] = bank_counts.get(h.bank_id, 0) + 1

    result = []
    # 第二次遍历计算递减序号（最近的练习序号最大）
    bank_idx = {}
    for h in reversed(all_histories):
        material_name = "未知教材"
        bank = db.query(QuestionBank).filter(QuestionBank.id == h.bank_id).first()
        if bank:
            mat = db.query(Material).filter(Material.id == bank.material_id).first()
            if mat:
                material_name = mat.filename

    for h in histories:
        wrong_ids = json.loads(h.wrong_ids) if h.wrong_ids else []
        accuracy = round(h.correct_count / h.total_questions * 100, 1) if h.total_questions > 0 else 0
        material_name = "未知教材"
        bank = db.query(QuestionBank).filter(QuestionBank.id == h.bank_id).first()
        if bank:
            mat = db.query(Material).filter(Material.id == bank.material_id).first()
            if mat:
                material_name = mat.filename
        # 计算这是该教材的第几次练习
        bank_idx[h.bank_id] = bank_idx.get(h.bank_id, 0) + 1
        seq = bank_idx[h.bank_id]
        result.append({
            "id": h.id,
            "bank_id": h.bank_id,
            "material_name": material_name,
            "sequence": seq,
            "total_questions": h.total_questions,
            "correct_count": h.correct_count,
            "wrong_count": len(wrong_ids),
            "accuracy": accuracy,
            "completed_at": h.completed_at,
        })
    return result


@router.get("/wrong")
def get_all_wrong(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """获取所有错题，按教材分组，每组含题目+答案+解析"""
    # 按 bank_id 聚合，每个 bank 只取最新的错题集
    groups = {}
    histories = (
        db.query(PracticeHistory)
        .filter(PracticeHistory.user_id == current_user.id)
        .order_by(PracticeHistory.completed_at.desc())
        .all()
    )

    for h in histories:
        if not h.wrong_ids:
            continue
        wrong_indices = json.loads(h.wrong_ids)
        if not wrong_indices:
            continue

        bank = db.query(QuestionBank).filter(
            QuestionBank.id == h.bank_id,
            QuestionBank.user_id == current_user.id
        ).first()
        if not bank:
            continue

        mat = db.query(Material).filter(Material.id == bank.material_id).first()
        material_name = mat.filename if mat else "未知教材"

        # 每个 bank 只取最新一次
        if h.bank_id in groups:
            # 已有更新的记录，跳过
            continue

        questions = json.loads(bank.questions_json)
        items = []
        for idx in wrong_indices:
            if 0 <= idx < len(questions):
                q = questions[idx]
                items.append({
                    "bank_id": h.bank_id,
                    "question_index": idx,
                    "question": q.get("question", ""),
                    "options": q.get("options", []),
                    "question_type": bank.question_type,
                    "answer": q.get("answer", ""),
                    "explanation": q.get("explanation", ""),
                })

        groups[h.bank_id] = {
            "bank_id": h.bank_id,
            "material_name": material_name,
            "wrong_count": len(items),
            "questions": items,
            "last_wrong_at": h.completed_at,
        }

    return list(groups.values())
