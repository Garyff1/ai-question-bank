import socket

import pytest

from app.app import _safe_web_target
from app.database import SessionLocal
from app.models import ApiConfig
from app.security.login_limiter import LoginAttemptLimiter
from app.security.network_targets import UnsafeApiBase, validate_api_base
from app.security.secret_cipher import decrypt_secret, encrypt_secret, is_encrypted_secret


def _public_dns(*_args, **_kwargs):
    return [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443))]


def test_api_base_rejects_private_and_credential_targets():
    blocked = [
        "http://127.0.0.1:8000",
        "https://10.0.0.1/v1",
        "https://169.254.169.254/latest/meta-data",
        "https://user:pass@example.com/v1",
        "https://example.com/v1?token=secret",
    ]
    for value in blocked:
        with pytest.raises(UnsafeApiBase):
            validate_api_base(value)


def test_desktop_mode_allows_only_explicit_loopback_http():
    assert validate_api_base("http://127.0.0.1:8123", allow_loopback=True) == "http://127.0.0.1:8123"
    with pytest.raises(UnsafeApiBase):
        validate_api_base("http://192.168.1.20:8123", allow_loopback=True)


def test_secret_cipher_round_trip_and_plaintext_compatibility():
    encrypted = encrypt_secret("sk-local-test-value")
    assert encrypted != "sk-local-test-value"
    assert is_encrypted_secret(encrypted)
    assert decrypt_secret(encrypted) == "sk-local-test-value"
    assert decrypt_secret("legacy-plaintext-value") == "legacy-plaintext-value"


def test_static_target_cannot_escape_web_root():
    assert _safe_web_target("../README.md") is None
    assert _safe_web_target("../../backend/.env") is None


def test_security_headers_are_added(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["x-frame-options"] == "DENY"
    assert response.headers["referrer-policy"] == "no-referrer"


def test_cors_rejects_unknown_origins_and_allows_known_site(client):
    denied = client.get("/health", headers={"Origin": "https://evil.example"})
    assert "access-control-allow-origin" not in denied.headers

    allowed = client.get("/health", headers={"Origin": "https://aichuti.ccwu.cc"})
    assert allowed.headers["access-control-allow-origin"] == "https://aichuti.ccwu.cc"
    assert "access-control-allow-credentials" not in allowed.headers


def test_unknown_api_path_returns_json_404_instead_of_homepage(client):
    response = client.get("/api/not-a-real-route")
    assert response.status_code == 404
    assert response.headers["content-type"].startswith("application/json")


def test_registration_rejects_weak_password_and_normalizes_email(client):
    weak = client.post(
        "/api/auth/register",
        json={"email": "person@example.com", "password": "short"},
    )
    assert weak.status_code == 422

    normalized = client.post(
        "/api/auth/register",
        json={"email": "  Person@Example.COM  ", "password": "SafePass123!"},
    )
    assert normalized.status_code == 200
    assert normalized.json()["email"] == "person@example.com"


def test_login_limiter_blocks_and_can_be_cleared():
    limiter = LoginAttemptLimiter(limit=2, window_seconds=60)
    limiter.record_failure("device:user")
    assert not limiter.is_blocked("device:user")
    limiter.record_failure("device:user")
    assert limiter.is_blocked("device:user")
    limiter.clear("device:user")
    assert not limiter.is_blocked("device:user")


def test_api_key_is_encrypted_at_rest(client, auth_headers, monkeypatch):
    monkeypatch.setattr("app.security.network_targets.socket.getaddrinfo", _public_dns)
    response = client.post(
        "/api/config/config",
        headers=auth_headers,
        json={
            "provider": "custom",
            "api_key": "sk-encryption-regression-test",
            "api_base": "https://provider.example/v1",
            "model_name": "model-test",
        },
    )
    assert response.status_code == 200, response.text

    db = SessionLocal()
    try:
        stored = db.query(ApiConfig).one()
        assert stored.api_key != "sk-encryption-regression-test"
        assert is_encrypted_secret(stored.api_key)
        assert decrypt_secret(stored.api_key) == "sk-encryption-regression-test"
    finally:
        db.close()


def test_legacy_plaintext_api_key_migrates_without_being_returned(client, auth_headers):
    db = SessionLocal()
    try:
        db.add(
            ApiConfig(
                user_id=1,
                provider="deepseek",
                api_key="legacy-plaintext-key",
                api_base="https://api.deepseek.com",
                model_name="deepseek-chat",
            )
        )
        db.commit()
    finally:
        db.close()

    response = client.get("/api/config/config", headers=auth_headers)
    assert response.status_code == 200
    assert "api_key" not in response.json()

    db = SessionLocal()
    try:
        stored = db.query(ApiConfig).one()
        assert is_encrypted_secret(stored.api_key)
        assert decrypt_secret(stored.api_key) == "legacy-plaintext-key"
    finally:
        db.close()


def test_invalid_file_magic_is_rejected(client, auth_headers):
    response = client.post(
        "/api/materials/upload",
        headers=auth_headers,
        files={"file": ("fake.pdf", b"not really a pdf", "application/pdf")},
    )
    assert response.status_code == 400
    assert "PDF" in response.json()["detail"]
