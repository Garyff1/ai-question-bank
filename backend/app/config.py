import os
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


class Settings:
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))
    DESKTOP_MODE: bool = _truthy(os.getenv("AIQB_DESKTOP_MODE")) or _truthy(os.getenv("DESKTOP_MODE"))
    RELOAD: bool = _truthy(os.getenv("RELOAD", "1")) and not DESKTOP_MODE

    DATABASE_URL: str = _database_url()
    SECRET_KEY: str = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY", "")
    OPENAI_API_BASE: str = os.getenv("OPENAI_API_BASE", "https://api.deepseek.com")
    AI_MODEL: str = os.getenv("AI_MODEL", "deepseek-v4-flash")

    MAX_FILE_SIZE: int = 50 * 1024 * 1024  # 50MB

    # v3 Phase 3 feature gates. Safe defaults are intentional: a release build
    # must never become a charging build merely because client code changed.
    OFFICIAL_AI_ENABLED: bool = _truthy(os.getenv("OFFICIAL_AI_ENABLED", "0"))
    SHADOW_BILLING_ENABLED: bool = _truthy(os.getenv("SHADOW_BILLING_ENABLED", "1"))
    PAYMENT_MOCK_ENABLED: bool = _truthy(os.getenv("PAYMENT_MOCK_ENABLED", "1"))
    WECHAT_PAY_ENABLED: bool = _truthy(os.getenv("WECHAT_PAY_ENABLED", "0"))
    ALIPAY_PAY_ENABLED: bool = _truthy(os.getenv("ALIPAY_PAY_ENABLED", "0"))
    REAL_CHARGE_ENABLED: bool = _truthy(os.getenv("REAL_CHARGE_ENABLED", "0"))

    OFFICIAL_AI_PROVIDER: str = os.getenv("OFFICIAL_AI_PROVIDER", "fake")
    OFFICIAL_AI_BASE_URL: str = os.getenv("OFFICIAL_AI_BASE_URL", "")
    OFFICIAL_AI_MODEL: str = os.getenv("OFFICIAL_AI_MODEL", "fake-question-model")
    OFFICIAL_AI_API_KEY: str = os.getenv("OFFICIAL_AI_API_KEY", "")

    WECHAT_APP_ID: str = os.getenv("WECHAT_APP_ID", "")
    WECHAT_MCH_ID: str = os.getenv("WECHAT_MCH_ID", "")
    WECHAT_API_V3_KEY: str = os.getenv("WECHAT_API_V3_KEY", "")
    WECHAT_PRIVATE_KEY_PATH: str = os.getenv("WECHAT_PRIVATE_KEY_PATH", "")
    WECHAT_CERT_SERIAL_NO: str = os.getenv("WECHAT_CERT_SERIAL_NO", "")

    ALIPAY_APP_ID: str = os.getenv("ALIPAY_APP_ID", "")
    ALIPAY_PRIVATE_KEY: str = os.getenv("ALIPAY_PRIVATE_KEY", "")
    ALIPAY_PUBLIC_KEY: str = os.getenv("ALIPAY_PUBLIC_KEY", "")
    ALIPAY_NOTIFY_URL: str = os.getenv("ALIPAY_NOTIFY_URL", "")

    DATA_ENCRYPTION_KEY: str = os.getenv("DATA_ENCRYPTION_KEY", "")
    QUOTE_TTL_SECONDS: int = int(os.getenv("QUOTE_TTL_SECONDS", "900"))
    GENERATION_TIMEOUT_SECONDS: int = int(os.getenv("GENERATION_TIMEOUT_SECONDS", "90"))


settings = Settings()
