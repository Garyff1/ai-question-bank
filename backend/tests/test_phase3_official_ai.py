import datetime as dt
import json

import pytest

from app.config import settings
from app.database import SessionLocal
from app.official_ai.models import OfficialAiAuditLog, OfficialAiQuote
from app.official_ai.migrations import PHASE3_TABLES, phase3_schema_ready, upgrade_phase3_schema
from app.official_ai.pricing import calculate_price
from app.official_ai.security import safe_json
from app.official_ai.service import transition


def register(client, email="phase3@example.com"):
    response = client.post(
        "/api/auth/register",
        json={"email": email, "password": "SafePass123!"},
    )
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def _quote(client, headers, count=5):
    response = client.post(
        "/api/official-ai/quotes",
        headers=headers,
        json={"questionCount": count, "questionTypes": ["choice"], "addOns": []},
    )
    assert response.status_code == 200, response.text
    return response.json()


def _order(client, headers, quote_id, suffix="001"):
    response = client.post(
        "/api/official-ai/orders",
        headers=headers,
        json={
            "quoteId": quote_id,
            "paymentChannel": "mock",
            "clientRequestId": f"client-request-{suffix}",
            "idempotencyKey": f"idempotency-{suffix}",
        },
    )
    assert response.status_code == 200, response.text
    return response.json()


def _get_order(client, headers, order_id):
    response = client.get(f"/api/official-ai/orders/{order_id}", headers=headers)
    assert response.status_code == 200, response.text
    return response.json()


def test_integer_fen_pricing():
    assert calculate_price(1).final_amount_fen == 50
    assert calculate_price(5).final_amount_fen == 50
    assert calculate_price(10).final_amount_fen == 100
    assert isinstance(calculate_price(20).final_amount_fen, int)


def test_phase3_schema_migration_is_idempotent():
    from app.database import engine

    for table in reversed(PHASE3_TABLES):
        table.drop(bind=engine, checkfirst=True)
    assert phase3_schema_ready(engine) is False
    upgrade_phase3_schema(engine)
    upgrade_phase3_schema(engine)
    assert phase3_schema_ready(engine) is True


def test_safe_feature_defaults(client):
    response = client.get("/api/official-ai/features")
    assert response.status_code == 200
    payload = response.json()
    assert payload["paymentMockEnabled"] is True
    assert payload["realChargeEnabled"] is False
    assert payload["wechatPayEnabled"] is False
    assert payload["alipayPayEnabled"] is False


def test_real_payment_callbacks_are_safely_disabled(client):
    assert client.post("/api/official-ai/payments/wechat/notify", json={}).status_code == 503
    assert client.post("/api/official-ai/payments/alipay/notify", json={}).status_code == 503


def test_quote_and_idempotent_order(client, auth_headers):
    quote = _quote(client, auth_headers, 8)
    assert quote["amountFen"] == 80
    first = _order(client, auth_headers, quote["quoteId"])
    second = _order(client, auth_headers, quote["quoteId"])
    assert first["orderId"] == second["orderId"]
    assert first["status"] == "awaiting_payment"
    assert first["isTest"] is True


def test_expired_quote_is_rejected(client, auth_headers):
    quote = _quote(client, auth_headers)
    db = SessionLocal()
    try:
        row = db.query(OfficialAiQuote).filter(OfficialAiQuote.id == quote["quoteId"]).one()
        row.expires_at = dt.datetime.utcnow() - dt.timedelta(seconds=1)
        db.commit()
    finally:
        db.close()
    response = client.post(
        "/api/official-ai/orders",
        headers=auth_headers,
        json={
            "quoteId": quote["quoteId"],
            "paymentChannel": "mock",
            "clientRequestId": "expired-client-request",
            "idempotencyKey": "expired-idempotency",
        },
    )
    assert response.status_code == 409


def test_tampered_payment_amount_is_rejected(client, auth_headers):
    order = _order(client, auth_headers, _quote(client, auth_headers)["quoteId"], "tamper")
    response = client.post(
        f"/api/official-ai/orders/{order['orderId']}/mock-pay",
        headers=auth_headers,
        json={"outcome": "success", "generationScenario": "success", "amountFen": 1},
    )
    assert response.status_code == 409


def test_mock_payment_success_and_duplicate_callback(client, auth_headers):
    order = _order(client, auth_headers, _quote(client, auth_headers, 5)["quoteId"], "success")
    url = f"/api/official-ai/orders/{order['orderId']}/mock-pay"
    first = client.post(url, headers=auth_headers, json={"outcome": "success", "generationScenario": "success"})
    assert first.status_code == 200
    assert first.json()["status"] == "paid"
    completed = _get_order(client, auth_headers, order["orderId"])
    assert completed["status"] == "success"
    assert len(completed["result"]) == 5
    second = client.post(url, headers=auth_headers, json={"outcome": "success", "generationScenario": "success"})
    assert second.status_code == 200
    assert second.json()["orderId"] == completed["orderId"]
    assert second.json()["status"] == "success"


@pytest.mark.parametrize("scenario", ["timeout", "invalid_json", "provider_error"])
def test_generation_failure_retries_then_refunds(client, auth_headers, scenario):
    order = _order(client, auth_headers, _quote(client, auth_headers)["quoteId"], scenario)
    response = client.post(
        f"/api/official-ai/orders/{order['orderId']}/mock-pay",
        headers=auth_headers,
        json={"outcome": "success", "generationScenario": scenario, "refundOutcome": "success"},
    )
    assert response.status_code == 200
    assert response.json()["status"] == "paid"
    assert _get_order(client, auth_headers, order["orderId"])["status"] == "refunded"


def test_failed_refund_can_be_retried_idempotently(client, auth_headers):
    order = _order(client, auth_headers, _quote(client, auth_headers)["quoteId"], "refund")
    paid = client.post(
        f"/api/official-ai/orders/{order['orderId']}/mock-pay",
        headers=auth_headers,
        json={"outcome": "success", "generationScenario": "timeout", "refundOutcome": "failure"},
    )
    assert paid.status_code == 200
    assert paid.json()["status"] == "paid"
    assert _get_order(client, auth_headers, order["orderId"])["status"] == "refunding"
    retried = client.post(
        f"/api/official-ai/orders/{order['orderId']}/mock-refund",
        headers=auth_headers,
        json={"outcome": "success"},
    )
    assert retried.status_code == 200
    assert retried.json()["status"] == "refunded"
    repeated = client.post(
        f"/api/official-ai/orders/{order['orderId']}/mock-refund",
        headers=auth_headers,
        json={"outcome": "success"},
    )
    assert repeated.status_code == 200
    assert repeated.json()["status"] == "refunded"


def test_order_ownership_is_enforced(client, auth_headers):
    order = _order(client, auth_headers, _quote(client, auth_headers)["quoteId"], "owner")
    other_headers = register(client, "other@example.com")
    response = client.get(f"/api/official-ai/orders/{order['orderId']}", headers=other_headers)
    assert response.status_code == 404


def test_real_channels_are_safely_disabled(client, auth_headers):
    quote = _quote(client, auth_headers)
    response = client.post(
        "/api/official-ai/orders",
        headers=auth_headers,
        json={
            "quoteId": quote["quoteId"],
            "paymentChannel": "wechat",
            "clientRequestId": "wechat-client-request",
            "idempotencyKey": "wechat-idempotency",
        },
    )
    assert response.status_code == 503


def test_log_redaction():
    encoded = safe_json(
        {
            "apiKey": "sk-super-secret-token",
            "Authorization": "Bearer abc.def.ghi",
            "nested": {"password": "NeverLogThis"},
        }
    )
    assert "super-secret" not in encoded
    assert "abc.def.ghi" not in encoded
    assert "NeverLogThis" not in encoded
    assert encoded.count("***REDACTED***") >= 3


def test_data_delete_removes_official_records(client, auth_headers):
    order = _order(client, auth_headers, _quote(client, auth_headers)["quoteId"], "delete")
    client.post(
        f"/api/official-ai/orders/{order['orderId']}/mock-pay",
        headers=auth_headers,
        json={"outcome": "success", "generationScenario": "success"},
    )
    response = client.delete("/api/official-ai/data", headers=auth_headers)
    assert response.status_code == 204
    listed = client.get("/api/official-ai/orders", headers=auth_headers)
    assert listed.status_code == 200
    assert listed.json()["items"] == []


def test_account_delete_requires_password_and_revokes_account(client, auth_headers):
    rejected = client.request(
        "DELETE",
        "/api/official-ai/account",
        headers=auth_headers,
        json={"password": "WrongPass123!"},
    )
    assert rejected.status_code == 403
    deleted = client.request(
        "DELETE",
        "/api/official-ai/account",
        headers=auth_headers,
        json={"password": "SafePass123!"},
    )
    assert deleted.status_code == 204
    assert client.get("/api/auth/me", headers=auth_headers).status_code == 401


def test_invalid_state_transition_raises(client, auth_headers):
    order_data = _order(client, auth_headers, _quote(client, auth_headers)["quoteId"], "state")
    db = SessionLocal()
    try:
        from app.official_ai.models import OfficialAiOrder

        order = db.query(OfficialAiOrder).filter(OfficialAiOrder.id == order_data["orderId"]).one()
        with pytest.raises(ValueError):
            transition(db, order, "success")
    finally:
        db.close()


def test_official_feature_gate_blocks_quotes(client, auth_headers, monkeypatch):
    monkeypatch.setattr(settings, "OFFICIAL_AI_ENABLED", False)
    response = client.post("/api/official-ai/quotes", headers=auth_headers, json={"questionCount": 5})
    assert response.status_code == 503
