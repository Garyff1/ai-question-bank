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
    OPENAI_API_BASE: str = os.getenv("OPENAI_API_BASE", "https://api.openai.com/v1")
    AI_MODEL: str = os.getenv("AI_MODEL", "gpt-3.5-turbo")

    MAX_FILE_SIZE: int = 50 * 1024 * 1024  # 50MB


settings = Settings()
