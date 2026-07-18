import datetime as dt

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, Text

from app.database import Base


def utcnow() -> dt.datetime:
    return dt.datetime.utcnow()


class OfficialAiQuote(Base):
    __tablename__ = "official_ai_quotes"

    id = Column(String(36), primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    service_type = Column(String(50), nullable=False, default="question_generation")
    question_count = Column(Integer, nullable=False)
    amount_fen = Column(Integer, nullable=False)
    currency = Column(String(8), nullable=False, default="CNY")
    breakdown_json = Column(Text, nullable=False)
    price_version = Column(String(32), nullable=False)
    request_hash = Column(String(64), nullable=False)
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)


class OfficialAiOrder(Base):
    __tablename__ = "official_ai_orders"

    id = Column(String(36), primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    quote_id = Column(String(36), ForeignKey("official_ai_quotes.id"), nullable=False)
    service_type = Column(String(50), nullable=False)
    question_count = Column(Integer, nullable=False)
    amount_fen = Column(Integer, nullable=False)
    currency = Column(String(8), nullable=False, default="CNY")
    payment_channel = Column(String(20), nullable=False, default="mock")
    status = Column(String(32), nullable=False, default="awaiting_payment", index=True)
    client_request_id = Column(String(80), nullable=False, unique=True, index=True)
    idempotency_key = Column(String(80), nullable=False, unique=True, index=True)
    provider_transaction_id = Column(String(100), nullable=True)
    generation_task_id = Column(String(36), nullable=True)
    result_json = Column(Text, nullable=True)
    failure_reason = Column(String(500), nullable=True)
    refund_attempts = Column(Integer, nullable=False, default=0)
    is_test = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    paid_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    refunded_at = Column(DateTime, nullable=True)


class OfficialAiGenerationTask(Base):
    __tablename__ = "official_ai_generation_tasks"

    id = Column(String(36), primary_key=True)
    order_id = Column(String(36), ForeignKey("official_ai_orders.id"), nullable=False, unique=True)
    status = Column(String(32), nullable=False, default="pending")
    scenario = Column(String(32), nullable=False, default="success")
    attempt_count = Column(Integer, nullable=False, default=0)
    result_json = Column(Text, nullable=True)
    error_code = Column(String(80), nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)


class OfficialAiUsageRecord(Base):
    __tablename__ = "official_ai_usage_records"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    request_id = Column(String(36), nullable=False, index=True)
    order_id = Column(String(36), ForeignKey("official_ai_orders.id"), nullable=True)
    provider = Column(String(50), nullable=False)
    model = Column(String(100), nullable=False)
    input_tokens = Column(Integer, nullable=False, default=0)
    output_tokens = Column(Integer, nullable=False, default=0)
    duration_ms = Column(Integer, nullable=False, default=0)
    retry_count = Column(Integer, nullable=False, default=0)
    requested_questions = Column(Integer, nullable=False, default=0)
    generated_questions = Column(Integer, nullable=False, default=0)
    success = Column(Boolean, nullable=False, default=False)
    failure_code = Column(String(100), nullable=True)
    estimated_cost_fen = Column(Integer, nullable=False, default=0)
    quoted_amount_fen = Column(Integer, nullable=False, default=0)
    theoretical_margin_fen = Column(Integer, nullable=False, default=0)
    material_length = Column(Integer, nullable=False, default=0)
    material_hash = Column(String(64), nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)


class OfficialAiAuditLog(Base):
    __tablename__ = "official_ai_audit_logs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    order_id = Column(String(36), nullable=True, index=True)
    event = Column(String(80), nullable=False)
    from_status = Column(String(32), nullable=True)
    to_status = Column(String(32), nullable=True)
    detail_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, nullable=False)
