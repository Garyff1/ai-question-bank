from app.config import settings
from app.official_ai.payments.base import PaymentResult, PaymentUnavailable


class WeChatPaymentProvider:
    """Safe adapter boundary. Real SDK/network calls are intentionally absent."""

    name = "wechat"
    implementation_ready = False

    @property
    def configured(self) -> bool:
        return bool(
            settings.REAL_CHARGE_ENABLED
            and settings.WECHAT_PAY_ENABLED
            and settings.WECHAT_APP_ID
            and settings.WECHAT_MCH_ID
            and settings.WECHAT_API_V3_KEY
            and settings.WECHAT_PRIVATE_KEY_PATH
            and settings.WECHAT_CERT_SERIAL_NO
        )

    def create_payment(self, *, order_id: str, amount_fen: int, outcome: str = "success") -> PaymentResult:
        raise PaymentUnavailable("微信支付适配层已准备，但真实商户配置或真实扣费开关未启用")

    def refund(self, *, order_id: str, transaction_id: str | None, amount_fen: int, outcome: str = "success") -> PaymentResult:
        raise PaymentUnavailable("微信退款适配层未启用")

    def verify_callback(self, payload: dict) -> PaymentResult:
        raise PaymentUnavailable("微信回调验签适配层未启用")
