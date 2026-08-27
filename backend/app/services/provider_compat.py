from typing import Any


from app.config import settings
from app.security.network_targets import validate_api_base


def normalize_api_base(api_base: str) -> str:
    return validate_api_base(api_base, allow_loopback=settings.DESKTOP_MODE)


def build_llm_headers(api_key: str, api_base: str) -> dict[str, str]:
    """Build OpenAI-compatible headers without logging the credential."""
    if "xiaomimimo.com" in api_base.lower():
        return {"api-key": api_key, "Content-Type": "application/json"}
    return {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }


def build_chat_payload(
    *,
    api_base: str,
    model: str,
    messages: list[dict[str, str]],
    max_tokens: int,
    temperature: float,
) -> dict[str, Any]:
    """Use the parameter names and defaults accepted by current providers."""
    base = api_base.lower()
    is_mimo = "xiaomimimo.com" in base
    is_kimi = "moonshot.cn" in base
    payload: dict[str, Any] = {"model": model, "messages": messages}
    if is_mimo:
        payload["max_completion_tokens"] = max_tokens
    else:
        payload["max_tokens"] = max_tokens
    if not is_mimo and not is_kimi:
        payload["temperature"] = temperature
    return payload
