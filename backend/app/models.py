import datetime
from sqlalchemy import Column, Integer, String, Text, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    materials = relationship("Material", back_populates="user", cascade="all, delete-orphan")
    question_banks = relationship("QuestionBank", back_populates="user", cascade="all, delete-orphan")
    practice_records = relationship("PracticeRecord", back_populates="user", cascade="all, delete-orphan")
    practice_histories = relationship("PracticeHistory", back_populates="user", cascade="all, delete-orphan")
    api_configs = relationship("ApiConfig", back_populates="user", cascade="all, delete-orphan")


class Material(Base):
    __tablename__ = "materials"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    filename = Column(String(255), nullable=False)
    content_text = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="materials")
    question_banks = relationship("QuestionBank", back_populates="material", cascade="all, delete-orphan")


class QuestionBank(Base):
    __tablename__ = "question_banks"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    material_id = Column(Integer, ForeignKey("materials.id"), nullable=False)
    question_type = Column(String(20), nullable=False)
    target_audience = Column(String(50), nullable=True)
    questions_json = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="question_banks")
    material = relationship("Material", back_populates="question_banks")
    practice_records = relationship("PracticeRecord", back_populates="question_bank", cascade="all, delete-orphan")


class PracticeRecord(Base):
    __tablename__ = "practice_records"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    question_bank_id = Column(Integer, ForeignKey("question_banks.id"), nullable=False)
    question_index = Column(Integer, nullable=False)
    user_answer = Column(String(500), nullable=False)
    is_correct = Column(Boolean, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="practice_records")
    question_bank = relationship("QuestionBank", back_populates="practice_records")


class PracticeHistory(Base):
    """每次练习记录（一次生成→答题算一次练习）"""
    __tablename__ = "practice_histories"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    bank_id = Column(Integer, ForeignKey("question_banks.id"), nullable=False)
    total_questions = Column(Integer, nullable=False, default=0)
    correct_count = Column(Integer, nullable=False, default=0)
    wrong_ids = Column(Text, nullable=True)
    completed_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="practice_histories")
    question_bank = relationship("QuestionBank")


class ApiConfig(Base):
    """用户自定义 API 配置"""
    __tablename__ = "api_configs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    provider = Column(String(50), nullable=False, default="custom")
    api_key = Column(String(500), nullable=False)
    api_base = Column(String(500), nullable=False)
    model_name = Column(String(100), nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="api_configs")
