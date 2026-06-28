import uvicorn
from dotenv import load_dotenv
from app.config import settings

load_dotenv()

if __name__ == "__main__":
    uvicorn.run(
        "app.app:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.RELOAD,
    )
