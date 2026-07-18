from pydantic import BaseModel, Field


class QuoteRequest(BaseModel):
    questionCount: int = Field(ge=1, le=100)
    serviceType: str = "question_generation"
    questionTypes: list[str] = Field(default_factory=lambda: ["choice"])
    addOns: list[str] = Field(default_factory=list)


class OrderCreateRequest(BaseModel):
    quoteId: str
    paymentChannel: str = "mock"
    clientRequestId: str = Field(min_length=8, max_length=80)
    idempotencyKey: str = Field(min_length=8, max_length=80)
    mockScenario: str = "success"


class MockPayRequest(BaseModel):
    outcome: str = "success"
    generationScenario: str = "success"
    refundOutcome: str = "success"
    amountFen: int | None = None


class MockRefundRequest(BaseModel):
    outcome: str = "success"


class AccountDeleteRequest(BaseModel):
    password: str = Field(min_length=6, max_length=200)


class LoginLikeRequest(BaseModel):
    email: str
    password: str
