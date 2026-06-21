from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import engine, Base
from app.routers import auth, materials, questions, practice, stats, api_config

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="AI题库 API",
    description="AI驱动的智能出题与练习系统后端服务",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/auth", tags=["认证"])
app.include_router(materials.router, prefix="/api/materials", tags=["资料管理"])
app.include_router(questions.router, prefix="/api/questions", tags=["出题"])
app.include_router(practice.router, prefix="/api/practice", tags=["答题练习"])
app.include_router(stats.router, prefix="/api/stats", tags=["学习统计"])
app.include_router(api_config.router, prefix="/api/config", tags=["API配置"])


@app.get("/")
async def root():
    return {"message": "AI题库 API 服务运行中", "version": "1.0.0"}
