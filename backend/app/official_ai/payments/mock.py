import uuid

from app.official_ai.payments.base import PaymentResult


class MockPaymentProvider:
    name = "mock"

    @property
    def configured(self) -> bool:
        return True

    def create_payment(self, *, order_id: str, amount_fen: int, outcome: str = "success") -> PaymentResult:
        transaction_id = f"mock_{uuid.uuid4().hex}"
        outcomes = {
            "success": PaymentResult(True, "paid", transaction_id, "模拟支付成功", amount_fen),
            "cancel": PaymentResult(False, "cancelled", None, "用户取消模拟支付", amount_fen),
            "failure": PaymentResult(False, "failed", None, "模拟支付失败", amount_fen),
            "timeout": PaymentResult(False, "timeout", None, "模拟支付超时", amount_fen),
        }
        return outcomes.get(outcome, outcomes["failure"])

    def refund(self, *, order_id: str, transaction_id: str | None, amount_fen: int, outcome: str = "success") -> PaymentResult:
        if outcome == "success":
            return PaymentResult(True, "refunded", f"refund_{uuid.uuid4().hex}", "模拟退款成功", amount_fen)
        return PaymentResult(False, "refunding", None, "模拟退款失败，等待重试", amount_fen)

    def verify_callback(self, payload: dict) -> PaymentResult:
        amount = int(payload.get("amountFen", 0))
        return self.create_payment(
            order_id=str(payload.get("orderId", "")),
            amount_fen=amount,
            outcome=str(payload.get("outcome", "success")),
        )
