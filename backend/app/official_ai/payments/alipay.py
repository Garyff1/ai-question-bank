from app.config import settings
from app.official_ai.payments.base import PaymentResult, PaymentUnavailable


class AlipayPaymentProvider:
    """Safe adapter boundary. Client return values are never trusted."""

    name = "alipay"
    implementation_ready = False

    @property
    def configured(self) -> bool:
        return bool(
            settings.REAL_CHARGE_ENABLED
            and settings.ALIPAY_PAY_ENABLED
            and settings.ALIPAY_APP_ID
            and settings.ALIPAY_PRIVATE_KEY
            and settings.ALIPAY_PUBLIC_KEY
            and settings.ALIPAY_NOTIFY_URL
        )

    def create_payment(self, *, order_id: str, amount_fen: int, outcome: str = "success") -> PaymentResult:
        raise PaymentUnavailable("支付宝适配层已准备，但真实应用配置或真实扣费开关未启用")

    def refund(self, *, order_id: str, transaction_id: str | None, amount_fen: int, outcome: str = "success") -> PaymentResult:
        raise PaymentUnavailable("支付宝退款适配层未启用")

    def verify_callback(self, payload: dict) -> PaymentResult:
        raise PaymentUnavailable("支付宝异步通知验签适配层未启用")
