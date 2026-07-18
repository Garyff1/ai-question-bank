import hashlib
import json
import re
from typing import Any


_SENSITIVE_KEY = re.compile(r"(api[_-]?key|authorization|token|secret|private[_-]?key|password)", re.I)


def redact(value: Any) -> Any:
    """Recursively remove secrets before values enter logs or audit rows."""
    if isinstance(value, dict):
        return {
            str(key): "***REDACTED***" if _SENSITIVE_KEY.search(str(key)) else redact(item)
            for key, item in value.items()
        }
    if isinstance(value, list):
        return [redact(item) for item in value]
    if isinstance(value, str):
        value = re.sub(r"(?i)bearer\s+[A-Za-z0-9._-]+", "Bearer ***REDACTED***", value)
        value = re.sub(r"\bsk-[A-Za-z0-9_-]{8,}\b", "sk-***REDACTED***", value)
    return value


def safe_json(value: Any) -> str:
    return json.dumps(redact(value), ensure_ascii=False, separators=(",", ":"))


def content_fingerprint(text: str) -> tuple[int, str]:
    encoded = text.encode("utf-8")
    return len(text), hashlib.sha256(encoded).hexdigest()
