import datetime as dt
import json
import uuid
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.config import settings
from app.database import SessionLocal
from app.official_ai.models import (
    OfficialAiAuditLog,
    OfficialAiGenerationTask,
    OfficialAiOrder,
    OfficialAiQuote,
    OfficialAiUsageRecord,
)
from app.official_ai.payments import (
    AlipayPaymentProvider,
    MockPaymentProvider,
    WeChatPaymentProvider,
)
from app.official_ai.pricing import quote_expired
from app.official_ai.providers import FakeAiProvider, OfficialAiProvider
from app.official_ai.security import safe_json


ALLOWED_TRANSITIONS: dict[str, set[str]] = {
    "pending": {"awaiting_payment", "closed"},
    "awaiting_payment": {"paid", "closed"},
    "paid": {"generating", "refunding"},
    "generating": {"success", "failed"},
    "failed": {"refunding", "closed"},
    "refunding": {"refunded"},
    "success": set(),
    "refunded": set(),
    "closed": set(),
}


def feature_flags() -> dict:
    wechat = WeChatPaymentProvider()
    alipay = AlipayPaymentProvider()
    return {
        "officialAiEnabled": settings.OFFICIAL_AI_ENABLED,
        "shadowBillingEnabled": settings.SHADOW_BILLING_ENABLED,
        "paymentMockEnabled": settings.PAYMENT_MOCK_ENABLED,
        "wechatPayEnabled": settings.WECHAT_PAY_ENABLED and wechat.configured,
        "alipayPayEnabled": settings.ALIPAY_PAY_ENABLED and alipay.configured,
        "realChargeEnabled": settings.REAL_CHARGE_ENABLED,
        "environment": "test" if not settings.REAL_CHARGE_ENABLED else "production",
    }


def _audit(
    db: Session,
    *,
    event: str,
    user_id: int | None,
    order: OfficialAiOrder | None = None,
    from_status: str | None = None,
    to_status: str | None = None,
    detail: dict | None = None,
) -> None:
    db.add(
        OfficialAiAuditLog(
            user_id=user_id,
            order_id=order.id if order else None,
            event=event,
            from_status=from_status,
            to_status=to_status,
            detail_json=safe_json(detail or {}),
        )
    )


def transition(db: Session, order: OfficialAiOrder, target: str, *, detail: dict | None = None) -> None:
    source = order.status
    if target == source:
        return
    if target not in ALLOWED_TRANSITIONS.get(source, set()):
        raise ValueError(f"invalid order transition: {source} -> {target}")
    order.status = target
    _audit(
        db,
        event="order_status_changed",
        user_id=order.user_id,
        order=order,
        from_status=source,
        to_status=target,
        detail=detail,
    )


def get_user_order(db: Session, *, user_id: int, order_id: str) -> OfficialAiOrder:
    order = db.query(OfficialAiOrder).filter(OfficialAiOrder.id == order_id).first()
    if not order or order.user_id != user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="订单不存在")
    return order


def create_order(
    db: Session,
    *,
    user_id: int,
    quote_id: str,
    payment_channel: str,
    client_request_id: str,
    idempotency_key: str,
) -> OfficialAiOrder:
    if not settings.OFFICIAL_AI_ENABLED:
        raise HTTPException(status_code=503, detail="官方 AI 服务暂未开放")
    existing = (
        db.query(OfficialAiOrder)
        .filter(
            (OfficialAiOrder.client_request_id == client_request_id)
            | (OfficialAiOrder.idempotency_key == idempotency_key)
        )
        .first()
    )
    if existing:
        if existing.user_id != user_id:
            raise HTTPException(status_code=409, detail="幂等键已被使用")
        return existing

    quote = db.query(OfficialAiQuote).filter(OfficialAiQuote.id == quote_id).first()
    if not quote or quote.user_id != user_id:
        raise HTTPException(status_code=404, detail="报价不存在")
    if quote_expired(quote):
        raise HTTPException(status_code=409, detail="报价已过期，请重新获取")
    if payment_channel not in {"mock", "wechat", "alipay"}:
        raise HTTPException(status_code=400, detail="不支持的支付方式")
    if payment_channel == "mock" and not settings.PAYMENT_MOCK_ENABLED:
        raise HTTPException(status_code=503, detail="模拟支付已关闭")
    if payment_channel != "mock":
        # Real channels remain unavailable unless the server owns all switches
        # and merchant configuration. A local client flag cannot bypass this.
        provider = WeChatPaymentProvider() if payment_channel == "wechat" else AlipayPaymentProvider()
        if not provider.configured or not provider.implementation_ready:
            raise HTTPException(status_code=503, detail=f"{payment_channel} 尚未配置")

    order = OfficialAiOrder(
        id=str(uuid.uuid4()),
        user_id=user_id,
        quote_id=quote.id,
        service_type=quote.service_type,
        question_count=quote.question_count,
        amount_fen=quote.amount_fen,
        currency=quote.currency,
        payment_channel=payment_channel,
        status="awaiting_payment",
        client_request_id=client_request_id,
        idempotency_key=idempotency_key,
        is_test=not settings.REAL_CHARGE_ENABLED or payment_channel == "mock",
    )
    db.add(order)
    _audit(db, event="order_created", user_id=user_id, order=order, detail={"amountFen": order.amount_fen})
    db.commit()
    db.refresh(order)
    return order


def serialize_order(order: OfficialAiOrder) -> dict:
    def iso(value: dt.datetime | None) -> str | None:
        return value.isoformat() + "Z" if value else None

    return {
        "orderId": order.id,
        "quoteId": order.quote_id,
        "serviceType": order.service_type,
        "questionCount": order.question_count,
        "amountFen": order.amount_fen,
        "currency": order.currency,
        "paymentChannel": order.payment_channel,
        "status": order.status,
        "clientRequestId": order.client_request_id,
        "generationTaskId": order.generation_task_id,
        "isTest": order.is_test,
        "failureReason": order.failure_reason,
        "result": json.loads(order.result_json) if order.result_json else None,
        "createdAt": iso(order.created_at),
        "paidAt": iso(order.paid_at),
        "completedAt": iso(order.completed_at),
        "refundedAt": iso(order.refunded_at),
    }


def process_generation(
    db: Session,
    *,
    order_id: str,
    scenario: str,
    refund_outcome: str = "success",
    provider: OfficialAiProvider | None = None,
) -> None:
    order = db.query(OfficialAiOrder).filter(OfficialAiOrder.id == order_id).first()
    if not order or order.status not in {"paid", "generating"}:
        return
    task = db.query(OfficialAiGenerationTask).filter(OfficialAiGenerationTask.order_id == order.id).first()
    if not task:
        task = OfficialAiGenerationTask(id=str(uuid.uuid4()), order_id=order.id, scenario=scenario)
        db.add(task)
        order.generation_task_id = task.id
    if order.status == "paid":
        transition(db, order, "generating")
    task.status = "running"
    db.commit()

    input_tokens = output_tokens = duration_ms = 0
    failure_code: str | None = None
    questions: list[dict] = []
    active_provider = provider or FakeAiProvider()
    for attempt in range(2):
        task.attempt_count = attempt + 1
        try:
            generated = active_provider.generate_questions(
                question_count=order.question_count,
                scenario=scenario,
            )
            questions = generated.questions
            input_tokens = generated.input_tokens
            output_tokens = generated.output_tokens
            duration_ms = generated.duration_ms
            failure_code = None
            break
        except RuntimeError as error:
            failure_code = str(error)

    estimated_cost = max(1, (input_tokens + output_tokens) // 1000) if not failure_code else 1
    db.add(
        OfficialAiUsageRecord(
            user_id=order.user_id,
            request_id=task.id,
            order_id=order.id,
            provider=active_provider.name,
            model=settings.OFFICIAL_AI_MODEL,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            duration_ms=duration_ms,
            retry_count=max(0, task.attempt_count - 1),
            requested_questions=order.question_count,
            generated_questions=len(questions),
            success=failure_code is None,
            failure_code=failure_code,
            estimated_cost_fen=estimated_cost,
            quoted_amount_fen=order.amount_fen,
            theoretical_margin_fen=order.amount_fen - estimated_cost,
            material_length=0,
            material_hash=None,
        )
    )

    if failure_code is None:
        task.status = "success"
        task.result_json = json.dumps(questions, ensure_ascii=False)
        order.result_json = task.result_json
        order.completed_at = dt.datetime.utcnow()
        transition(db, order, "success")
        db.commit()
        return

    task.status = "failed"
    task.error_code = failure_code
    order.failure_reason = failure_code
    transition(db, order, "failed", detail={"failureCode": failure_code, "attempts": task.attempt_count})
    transition(db, order, "refunding")
    order.refund_attempts += 1
    refund = MockPaymentProvider().refund(
        order_id=order.id,
        transaction_id=order.provider_transaction_id,
        amount_fen=order.amount_fen,
        outcome=refund_outcome,
    )
    if refund.success:
        order.refunded_at = dt.datetime.utcnow()
        transition(db, order, "refunded")
    else:
        _audit(
            db,
            event="refund_retry_required",
            user_id=order.user_id,
            order=order,
            detail={"attempt": order.refund_attempts},
        )
    db.commit()


def mock_pay_order(
    db: Session,
    *,
    user_id: int,
    order_id: str,
    outcome: str,
    generation_scenario: str,
    refund_outcome: str,
    amount_fen: int | None,
    process_now: bool = True,
) -> OfficialAiOrder:
    if not settings.PAYMENT_MOCK_ENABLED or settings.REAL_CHARGE_ENABLED:
        raise HTTPException(status_code=503, detail="模拟支付不可用")
    order = get_user_order(db, user_id=user_id, order_id=order_id)
    if amount_fen is not None and amount_fen != order.amount_fen:
        _audit(db, event="payment_amount_mismatch", user_id=user_id, order=order, detail={"receivedFen": amount_fen})
        db.commit()
        raise HTTPException(status_code=409, detail="支付金额与订单不一致")
    if order.status in {"paid", "generating", "success", "failed", "refunding", "refunded"}:
        return order
    if order.status != "awaiting_payment":
        raise HTTPException(status_code=409, detail="当前订单状态不能支付")

    result = MockPaymentProvider().create_payment(order_id=order.id, amount_fen=order.amount_fen, outcome=outcome)
    _audit(db, event="mock_payment_attempt", user_id=user_id, order=order, detail={"outcome": result.status})
    if not result.success:
        if result.status == "cancelled":
            transition(db, order, "closed", detail={"reason": "user_cancelled"})
        db.commit()
        return order
    order.provider_transaction_id = result.transaction_id
    order.paid_at = dt.datetime.utcnow()
    transition(db, order, "paid")
    db.commit()
    if process_now:
        process_generation(
            db,
            order_id=order.id,
            scenario=generation_scenario,
            refund_outcome=refund_outcome,
        )
        db.refresh(order)
    return order


def run_generation_job(order_id: str, scenario: str, refund_outcome: str = "success") -> None:
    """Background-task entry point with an isolated database session."""
    db = SessionLocal()
    try:
        process_generation(db, order_id=order_id, scenario=scenario, refund_outcome=refund_outcome)
    finally:
        db.close()


def retry_mock_refund(db: Session, *, user_id: int, order_id: str, outcome: str = "success") -> OfficialAiOrder:
    if not settings.PAYMENT_MOCK_ENABLED or settings.REAL_CHARGE_ENABLED:
        raise HTTPException(status_code=503, detail="模拟退款不可用")
    order = get_user_order(db, user_id=user_id, order_id=order_id)
    if order.status == "refunded":
        return order
    if order.status != "refunding" or order.payment_channel != "mock":
        raise HTTPException(status_code=409, detail="当前订单无需模拟退款")
    order.refund_attempts += 1
    refund = MockPaymentProvider().refund(
        order_id=order.id,
        transaction_id=order.provider_transaction_id,
        amount_fen=order.amount_fen,
        outcome=outcome,
    )
    _audit(
        db,
        event="mock_refund_attempt",
        user_id=user_id,
        order=order,
        detail={"outcome": refund.status, "attempt": order.refund_attempts},
    )
    if refund.success:
        order.refunded_at = dt.datetime.utcnow()
        transition(db, order, "refunded")
    db.commit()
    db.refresh(order)
    return order


def delete_official_data(db: Session, user_id: int) -> None:
    order_ids = [value[0] for value in db.query(OfficialAiOrder.id).filter(OfficialAiOrder.user_id == user_id).all()]
    if order_ids:
        db.query(OfficialAiGenerationTask).filter(OfficialAiGenerationTask.order_id.in_(order_ids)).delete(
            synchronize_session=False
        )
        db.query(OfficialAiUsageRecord).filter(OfficialAiUsageRecord.order_id.in_(order_ids)).delete(
            synchronize_session=False
        )
        db.query(OfficialAiAuditLog).filter(OfficialAiAuditLog.order_id.in_(order_ids)).delete(
            synchronize_session=False
        )
    db.query(OfficialAiOrder).filter(OfficialAiOrder.user_id == user_id).delete(synchronize_session=False)
    db.query(OfficialAiQuote).filter(OfficialAiQuote.user_id == user_id).delete(synchronize_session=False)
    db.query(OfficialAiUsageRecord).filter(OfficialAiUsageRecord.user_id == user_id).delete(synchronize_session=False)
    db.query(OfficialAiAuditLog).filter(OfficialAiAuditLog.user_id == user_id).delete(synchronize_session=False)
    db.commit()
