import os
from pathlib import Path

import pytest


TEST_DB = Path(__file__).with_name("phase3_test.db")
os.environ["DATABASE_URL"] = f"sqlite:///{TEST_DB.as_posix()}"
os.environ["SECRET_KEY"] = "phase3-test-secret"
os.environ["OFFICIAL_AI_ENABLED"] = "1"
os.environ["SHADOW_BILLING_ENABLED"] = "1"
os.environ["PAYMENT_MOCK_ENABLED"] = "1"
os.environ["REAL_CHARGE_ENABLED"] = "0"
os.environ["WECHAT_PAY_ENABLED"] = "0"
os.environ["ALIPAY_PAY_ENABLED"] = "0"

from fastapi.testclient import TestClient  # noqa: E402

from app.app import app  # noqa: E402
from app.database import Base, engine  # noqa: E402


@pytest.fixture(autouse=True)
def clean_database():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield


@pytest.fixture(scope="session", autouse=True)
def remove_test_database():
    yield
    engine.dispose()
    if TEST_DB.exists():
        TEST_DB.unlink()


@pytest.fixture()
def client():
    with TestClient(app) as test_client:
        yield test_client


def register(client: TestClient, email: str = "phase3@example.com") -> dict[str, str]:
    response = client.post("/api/auth/register", json={"email": email, "password": "SafePass123!"})
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


@pytest.fixture()
def auth_headers(client):
    return register(client)
