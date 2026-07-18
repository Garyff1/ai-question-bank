from dataclasses import dataclass
from typing import Protocol


class PaymentUnavailable(RuntimeError):
    pass


@dataclass(frozen=True)
class PaymentResult:
    success: bool
    status: str
    transaction_id: str | None = None
    message: str = ""
    amount_fen: int | None = None


class PaymentProvider(Protocol):
    name: str

    @property
    def configured(self) -> bool: ...

    def create_payment(self, *, order_id: str, amount_fen: int, outcome: str = "success") -> PaymentResult: ...

    def refund(self, *, order_id: str, transaction_id: str | None, amount_fen: int, outcome: str = "success") -> PaymentResult: ...

    def verify_callback(self, payload: dict) -> PaymentResult: ...
