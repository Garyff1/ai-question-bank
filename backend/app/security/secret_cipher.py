from cryptography.fernet import Fernet, InvalidToken

from app.config import settings


_PREFIX = "enc:v1:"
_cipher = Fernet(settings.DATA_ENCRYPTION_KEY.encode("ascii"))


def is_encrypted_secret(value: str) -> bool:
    return str(value or "").startswith(_PREFIX)


def encrypt_secret(value: str) -> str:
    normalized = str(value or "").strip()
    if not normalized:
        raise ValueError("Secret cannot be empty")
    if is_encrypted_secret(normalized):
        decrypt_secret(normalized)
        return normalized
    token = _cipher.encrypt(normalized.encode("utf-8")).decode("ascii")
    return _PREFIX + token


def decrypt_secret(value: str) -> str:
    normalized = str(value or "").strip()
    if not normalized:
        return ""
    if not is_encrypted_secret(normalized):
        return normalized
    try:
        return _cipher.decrypt(normalized[len(_PREFIX) :].encode("ascii")).decode("utf-8")
    except (InvalidToken, UnicodeDecodeError) as exc:
        raise ValueError("Stored API credential cannot be decrypted") from exc
