from app.services.provider_compat import build_chat_payload


def test_health_and_legacy_status_remain_available(client):
    health = client.get("/health")
    assert health.status_code == 200
    assert health.json()["ok"] is True

    status = client.get("/api/status")
    assert status.status_code == 200
    assert "AI题库" in status.json()["message"]


def test_official_ai_commercial_routes_are_removed(client):
    # GET unknown paths intentionally fall back to the static SPA homepage, so
    # route removal is asserted against the API schema instead of HTTP 404.
    paths = client.get("/openapi.json").json()["paths"]
    assert not any(path.startswith("/api/official-ai") for path in paths)


def test_normal_auth_and_material_routes_remain_available(client, auth_headers):
    me = client.get("/api/auth/me", headers=auth_headers)
    assert me.status_code == 200
    assert me.json()["email"] == "byok-test@example.com"

    materials = client.get("/api/materials", headers=auth_headers)
    assert materials.status_code == 200
    assert materials.json() == []


def test_provider_templates_follow_current_byok_defaults(client):
    response = client.get("/api/config/providers")
    assert response.status_code == 200
    providers = response.json()
    assert providers["deepseek"]["model"] == "deepseek-v4-flash"
    assert providers["zhipu"]["model"] == "glm-5.2"
    assert providers["mimo"]["model"] == "mimo-v2.5-pro"
    assert providers["kimi"]["model"] == "kimi-k3"
    assert "siliconflow" in providers


def test_provider_specific_payload_avoids_invalid_parameters():
    messages = [{"role": "user", "content": "hello"}]
    mimo = build_chat_payload(
        api_base="https://api.xiaomimimo.com/v1",
        model="mimo-v2.5-pro",
        messages=messages,
        max_tokens=64,
        temperature=0.2,
    )
    assert mimo["max_completion_tokens"] == 64
    assert "max_tokens" not in mimo
    assert "temperature" not in mimo

    kimi = build_chat_payload(
        api_base="https://api.moonshot.cn/v1",
        model="kimi-k3",
        messages=messages,
        max_tokens=64,
        temperature=0.2,
    )
    assert kimi["max_tokens"] == 64
    assert "temperature" not in kimi
