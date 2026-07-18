import datetime as dt
import hashlib
import json
import uuid
from dataclasses import dataclass

from sqlalchemy.orm import Session

from app.config import settings
from app.official_ai.models import OfficialAiQuote


PRICE_VERSION = "phase3-shadow-v1"


@dataclass(frozen=True)
class PriceBreakdown:
    question_count: int
    base_amount_fen: int
    extra_amount_fen: int
    final_amount_fen: int

    def items(self) -> list[dict]:
        return [
            {
                "code": "ordinary_questions",
                "labelZh": f"普通题目：{self.question_count}题",
                "labelEn": f"Ordinary questions: {self.question_count}",
                "amountFen": self.final_amount_fen,
                "free": False,
            },
            {"code": "local_chart", "labelZh": "本地图表", "labelEn": "Local charts", "amountFen": 0, "free": True},
            {"code": "system_tts", "labelZh": "系统语音", "labelEn": "System TTS", "amountFen": 0, "free": True},
            {"code": "local_ocr", "labelZh": "本地OCR", "labelEn": "Local OCR", "amountFen": 0, "free": True},
        ]


def calculate_price(question_count: int) -> PriceBreakdown:
    if question_count < 1 or question_count > 100:
        raise ValueError("question_count must be between 1 and 100")
    # Initial shadow price: five questions cost 50 fen; each additional
    # question costs 10 fen. Smaller requests still reserve the 50-fen base.
    base = 50
    extra = max(0, question_count - 5) * 10
    return PriceBreakdown(question_count, base, extra, base + extra)


def create_quote(
    db: Session,
    *,
    user_id: int,
    question_count: int,
    service_type: str,
    question_types: list[str] | None = None,
    add_ons: list[str] | None = None,
) -> OfficialAiQuote:
    price = calculate_price(question_count)
    now = dt.datetime.utcnow()
    request_payload = json.dumps(
        {
            "userId": user_id,
            "serviceType": service_type,
            "questionCount": question_count,
            "questionTypes": sorted(question_types or []),
            "addOns": sorted(add_ons or []),
            "priceVersion": PRICE_VERSION,
        },
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    request_hash = hashlib.sha256(request_payload.encode()).hexdigest()
    quote = OfficialAiQuote(
        id=str(uuid.uuid4()),
        user_id=user_id,
        service_type=service_type,
        question_count=question_count,
        amount_fen=price.final_amount_fen,
        currency="CNY",
        breakdown_json=json.dumps(price.items(), ensure_ascii=False),
        price_version=PRICE_VERSION,
        request_hash=request_hash,
        expires_at=now + dt.timedelta(seconds=settings.QUOTE_TTL_SECONDS),
    )
    db.add(quote)
    db.commit()
    db.refresh(quote)
    return quote


def quote_expired(quote: OfficialAiQuote, now: dt.datetime | None = None) -> bool:
    return quote.expires_at <= (now or dt.datetime.utcnow())


def pricing_catalog() -> dict:
    return {
        "currency": "CNY",
        "priceVersion": PRICE_VERSION,
        "ordinaryQuestions": {"baseQuestionCount": 5, "baseAmountFen": 50, "extraQuestionFen": 10},
        "freeCapabilities": [
            "bring_your_own_key",
            "existing_practice",
            "mistake_review",
            "existing_challenge",
            "existing_paper",
            "local_ocr",
            "local_chart",
            "system_tts",
            "history_and_explanations",
        ],
        "shadowOnlyCapabilities": [
            "ai_paper",
            "dynamic_challenge",
            "cloud_voice",
            "ai_image",
            "enhanced_ocr",
            "long_explanation",
        ],
    }
