import os
import base64
import secrets
import sys
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()


def _truthy(value: str | None) -> bool:
    return str(value or "").strip().lower() in {"1", "true", "yes", "on"}


def _default_user_data_dir() -> Path:
    """Return a writable per-user directory for the bundled desktop app."""
    if os.getenv("AIQB_USER_DATA_DIR"):
        return Path(os.environ["AIQB_USER_DATA_DIR"]).expanduser()

    if sys.platform.startswith("win"):
        root = os.getenv("APPDATA") or os.getenv("LOCALAPPDATA") or str(Path.home())
        return Path(root) / "AI题库"
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / "AI题库"
    return Path(os.getenv("XDG_DATA_HOME", Path.home() / ".local" / "share")) / "ai-question-bank"


def _database_url() -> str:
    """Resolve DATABASE_URL, moving the desktop SQLite DB out of the install dir."""
    if _truthy(os.getenv("AIQB_DESKTOP_MODE")) or os.getenv("AIQB_USER_DATA_DIR"):
        if os.getenv("AIQB_DESKTOP_DATABASE_URL"):
            return os.environ["AIQB_DESKTOP_DATABASE_URL"]
        data_dir = _default_user_data_dir()
        data_dir.mkdir(parents=True, exist_ok=True)
        return "sqlite:///" + (data_dir / "ai_question_bank.db").as_posix()

    if os.getenv("DATABASE_URL"):
        return os.environ["DATABASE_URL"]

    return "sqlite:///./ai_question_bank.db"


def _environment() -> str:
    return os.getenv("AIQB_ENVIRONMENT", os.getenv("ENVIRONMENT", "development")).strip().lower()


def _secret_directory() -> Path:
    configured = os.getenv("AIQB_SECRET_DIR")
    target = Path(configured).expanduser() if configured else _default_user_data_dir()
    target.mkdir(parents=True, exist_ok=True)
    return target


def _load_or_create_secret(
    environment_name: str,
    filename: str,
    generator,
) -> str:
    configured = os.getenv(environment_name, "").strip()
    placeholders = {
        "your-secret-key-change-in-production",
        "replace-with-a-long-random-secret",
        "replace-with-a-random-fernet-key",
    }
    if configured and configured not in placeholders:
        return configured

    if _environment() in {"production", "prod"}:
        raise RuntimeError(f"{environment_name} must be configured in production")

    path = _secret_directory() / filename
    if path.exists():
        existing = path.read_text(encoding="utf-8").strip()
        if existing:
            return existing

    value = generator()
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(value, encoding="utf-8")
    try:
        temporary.chmod(0o600)
    except OSError:
        pass
    temporary.replace(path)
    return value


def _jwt_secret() -> str:
    return _load_or_create_secret(
        "SECRET_KEY",
        ".jwt_secret",
        lambda: secrets.token_urlsafe(48),
    )


def _data_encryption_key() -> str:
    return _load_or_create_secret(
        "DATA_ENCRYPTION_KEY",
        ".data_encryption_key",
        lambda: base64.urlsafe_b64encode(secrets.token_bytes(32)).decode("ascii"),
    )


def _cors_origins() -> list[str]:
    raw = os.getenv("CORS_ORIGINS", "")
    if raw.strip():
        return [origin.strip().rstrip("/") for origin in raw.split(",") if origin.strip()]
    return [
        "tauri://localhost",
        "http://tauri.localhost",
        "https://aichuti.ccwu.cc",
    ]


class Settings:
    ENVIRONMENT: str = _environment()
    HOST: str = os.getenv("HOST", "127.0.0.1")
    PORT: int = int(os.getenv("PORT", "8000"))
    DESKTOP_MODE: bool = _truthy(os.getenv("AIQB_DESKTOP_MODE")) or _truthy(os.getenv("DESKTOP_MODE"))
    RELOAD: bool = _truthy(os.getenv("RELOAD", "1")) and not DESKTOP_MODE

    DATABASE_URL: str = _database_url()
    SECRET_KEY: str = _jwt_secret()
    DATA_ENCRYPTION_KEY: str = _data_encryption_key()
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY", "")
    OPENAI_API_BASE: str = os.getenv("OPENAI_API_BASE", "https://api.deepseek.com")
    AI_MODEL: str = os.getenv("AI_MODEL", "deepseek-v4-flash")

    MAX_FILE_SIZE: int = 50 * 1024 * 1024  # 50MB
    CORS_ORIGINS: list[str] = _cors_origins()
    CORS_ORIGIN_REGEX: str = os.getenv(
        "CORS_ORIGIN_REGEX",
        r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    )

settings = Settings()
