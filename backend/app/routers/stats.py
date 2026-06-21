from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.database import get_db
from app.models import User, PracticeRecord, PracticeHistory
from app.utils.auth import get_current_user

router = APIRouter()


@router.get("")
def get_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    total = db.query(func.count(PracticeRecord.id)).filter(
        PracticeRecord.user_id == current_user.id
    ).scalar() or 0

    correct = db.query(func.count(PracticeRecord.id)).filter(
        PracticeRecord.user_id == current_user.id,
        PracticeRecord.is_correct == True,
    ).scalar() or 0

    last_record = (
        db.query(PracticeRecord.created_at)
        .filter(PracticeRecord.user_id == current_user.id)
        .order_by(PracticeRecord.created_at.desc())
        .first()
    )

    practice_count = db.query(func.count(PracticeHistory.id)).filter(
        PracticeHistory.user_id == current_user.id
    ).scalar() or 0

    accuracy = round(correct / total * 100, 1) if total > 0 else 0.0

    return {
        "total_questions": total,
        "correct_count": correct,
        "accuracy": accuracy,
        "last_practice_time": last_record[0] if last_record else None,
        "practice_count": practice_count,
    }
