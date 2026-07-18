from sqlalchemy import Engine, inspect

from app.official_ai.models import (
    OfficialAiAuditLog,
    OfficialAiGenerationTask,
    OfficialAiOrder,
    OfficialAiQuote,
    OfficialAiUsageRecord,
)


PHASE3_TABLES = (
    OfficialAiQuote.__table__,
    OfficialAiOrder.__table__,
    OfficialAiGenerationTask.__table__,
    OfficialAiUsageRecord.__table__,
    OfficialAiAuditLog.__table__,
)


def upgrade_phase3_schema(engine: Engine) -> None:
    """Idempotent development migration; production still requires Alembic review."""
    for table in PHASE3_TABLES:
        table.create(bind=engine, checkfirst=True)


def phase3_schema_ready(engine: Engine) -> bool:
    existing = set(inspect(engine).get_table_names())
    return all(table.name in existing for table in PHASE3_TABLES)
