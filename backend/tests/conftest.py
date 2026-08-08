import os
from pathlib import Path

import pytest


TEST_DB = Path(__file__).with_name("byok_backend_test.db")
os.environ["DATABASE_URL"] = f"sqlite:///{TEST_DB.as_posix()}"
os.environ["SECRET_KEY"] = "byok-backend-test-secret"

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


def register(client: TestClient, email: str = "byok-test@example.com") -> dict[str, str]:
    response = client.post("/api/auth/register", json={"email": email, "password": "SafePass123!"})
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


@pytest.fixture()
def auth_headers(client):
    return register(client)
