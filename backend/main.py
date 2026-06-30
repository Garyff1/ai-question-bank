import traceback
from pathlib import Path

import uvicorn
from dotenv import load_dotenv

from app.config import settings

load_dotenv()


def _desktop_log_file() -> Path | None:
    if not settings.DESKTOP_MODE:
        return None

    data_dir = Path(settings.DATABASE_URL.replace("sqlite:///", "")).parent
    data_dir.mkdir(parents=True, exist_ok=True)
    return data_dir / "backend.log"


def _write_desktop_log(message: str) -> None:
    log_file = _desktop_log_file()
    if not log_file:
        return
    with log_file.open("a", encoding="utf-8") as f:
        f.write(message.rstrip() + "\n")


if __name__ == "__main__":
    try:
        _write_desktop_log(
            f"Starting backend on {settings.HOST}:{settings.PORT}; "
            f"database={settings.DATABASE_URL}; reload={settings.RELOAD}"
        )
        run_options = {
            "host": settings.HOST,
            "port": settings.PORT,
            "reload": settings.RELOAD,
        }
        if settings.DESKTOP_MODE:
            run_options["log_config"] = None
            run_options["access_log"] = False

        uvicorn.run("app.app:app", **run_options)
    except Exception:
        _write_desktop_log(traceback.format_exc())
        raise
