import json

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, Request, status
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import User
from app.official_ai.models import OfficialAiOrder, OfficialAiUsageRecord
from app.official_ai.payments import AlipayPaymentProvider, PaymentUnavailable, WeChatPaymentProvider
from app.official_ai.pricing import create_quote, pricing_catalog
from app.official_ai.schemas import (
    AccountDeleteRequest,
    MockPayRequest,
    MockRefundRequest,
    OrderCreateRequest,
    QuoteRequest,
)
from app.official_ai.service import (
    create_order,
    delete_official_data,
    feature_flags,
    get_user_order,
    mock_pay_order,
    retry_mock_refund,
    run_generation_job,
    serialize_order,
)
from app.utils.auth import get_current_user, verify_password


router = APIRouter()


@router.get("/features")
def get_features():
    """Return server-owned feature gates; local client flags cannot override them."""
    return feature_flags()


@router.get("/pricing")
def get_pricing():
    return pricing_catalog()


@router.post("/payments/wechat/notify")
async def wechat_notify(request: Request):
    provider = WeChatPaymentProvider()
    if not provider.configured or not provider.implementation_ready:
        raise HTTPException(status_code=503, detail="微信支付回调适配层尚未启用")
    try:
        return provider.verify_callback(await request.json())
    except PaymentUnavailable as error:
        raise HTTPException(status_code=503, detail=str(error)) from error


@router.post("/payments/alipay/notify")
async def alipay_notify(request: Request):
    provider = AlipayPaymentProvider()
    if not provider.configured or not provider.implementation_ready:
        raise HTTPException(status_code=503, detail="支付宝回调适配层尚未启用")
    try:
        return provider.verify_callback(await request.json())
    except PaymentUnavailable as error:
        raise HTTPException(status_code=503, detail=str(error)) from error


@router.post("/quotes")
def post_quote(
    request: QuoteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not settings.OFFICIAL_AI_ENABLED:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="官方 AI 服务暂未开放")
    quote = create_quote(
        db,
        user_id=current_user.id,
        question_count=request.questionCount,
        service_type=request.serviceType,
        question_types=request.questionTypes,
        add_ons=request.addOns,
    )
    return {
        "quoteId": quote.id,
        "serviceType": quote.service_type,
        "questionCount": quote.question_count,
        "amountFen": quote.amount_fen,
        "currency": quote.currency,
        "breakdown": json.loads(quote.breakdown_json),
        "priceVersion": quote.price_version,
        "expiresAt": quote.expires_at.isoformat() + "Z",
    }


@router.post("/orders")
def post_order(
    request: OrderCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    order = create_order(
        db,
        user_id=current_user.id,
        quote_id=request.quoteId,
        payment_channel=request.paymentChannel,
        client_request_id=request.clientRequestId,
        idempotency_key=request.idempotencyKey,
    )
    return serialize_order(order)


@router.get("/orders")
def list_orders(
    order_status: str | None = Query(default=None, alias="status"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = db.query(OfficialAiOrder).filter(OfficialAiOrder.user_id == current_user.id)
    if order_status:
        query = query.filter(OfficialAiOrder.status == order_status)
    orders = query.order_by(OfficialAiOrder.created_at.desc()).all()
    return {"items": [serialize_order(order) for order in orders]}


@router.get("/orders/{order_id}")
def get_order(
    order_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return serialize_order(get_user_order(db, user_id=current_user.id, order_id=order_id))


@router.post("/orders/{order_id}/mock-pay")
def mock_pay(
    order_id: str,
    request: MockPayRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    order = mock_pay_order(
        db,
        user_id=current_user.id,
        order_id=order_id,
        outcome=request.outcome,
        generation_scenario=request.generationScenario,
        refund_outcome=request.refundOutcome,
        amount_fen=request.amountFen,
        process_now=False,
    )
    if order.status == "paid":
        background_tasks.add_task(
            run_generation_job,
            order.id,
            request.generationScenario,
            request.refundOutcome,
        )
    return serialize_order(order)


@router.post("/orders/{order_id}/mock-refund")
def mock_refund(
    order_id: str,
    request: MockRefundRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return serialize_order(
        retry_mock_refund(db, user_id=current_user.id, order_id=order_id, outcome=request.outcome)
    )


@router.post("/orders/{order_id}/close")
def close_order(
    order_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    order = get_user_order(db, user_id=current_user.id, order_id=order_id)
    if order.status == "closed":
        return serialize_order(order)
    if order.status != "awaiting_payment":
        raise HTTPException(status_code=409, detail="当前订单无法关闭")
    from app.official_ai.service import transition

    transition(db, order, "closed", detail={"source": "user"})
    db.commit()
    db.refresh(order)
    return serialize_order(order)


@router.get("/usage")
def list_usage(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    records = (
        db.query(OfficialAiUsageRecord)
        .filter(OfficialAiUsageRecord.user_id == current_user.id)
        .order_by(OfficialAiUsageRecord.created_at.desc())
        .limit(100)
        .all()
    )
    return {
        "shadowBilling": True,
        "items": [
            {
                "requestId": record.request_id,
                "orderId": record.order_id,
                "provider": record.provider,
                "model": record.model,
                "inputTokens": record.input_tokens,
                "outputTokens": record.output_tokens,
                "durationMs": record.duration_ms,
                "retryCount": record.retry_count,
                "questionCount": record.requested_questions,
                "generatedCount": record.generated_questions,
                "success": record.success,
                "failureCode": record.failure_code,
                "estimatedCostFen": record.estimated_cost_fen,
                "quotedAmountFen": record.quoted_amount_fen,
                "theoreticalMarginFen": record.theoretical_margin_fen,
                "createdAt": record.created_at.isoformat() + "Z",
            }
            for record in records
        ],
    }


@router.delete("/data", status_code=status.HTTP_204_NO_CONTENT)
def delete_cloud_data(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    delete_official_data(db, current_user.id)
    return None


@router.delete("/account", status_code=status.HTTP_204_NO_CONTENT)
def delete_account(
    request: AccountDeleteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not verify_password(request.password, current_user.password_hash):
        raise HTTPException(status_code=403, detail="密码验证失败，账户未删除")
    delete_official_data(db, current_user.id)
    db.delete(current_user)
    db.commit()
    return None
