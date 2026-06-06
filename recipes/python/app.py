"""Runnable hello-world: HTTP + Postgres (ORM, migrate-on-start) + Valkey cache + OTLP.

This is the copyable reference for the quickstart stack. 12-factor: all config via env,
logs to stdout. Telemetry is emitted automatically by `opentelemetry-instrument` (see Dockerfile)
when OTEL_SDK_DISABLED=false — no code changes needed.
"""
import os

from fastapi import FastAPI
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column
import redis

PG_URL = (
    f"postgresql+psycopg://{os.environ['POSTGRES_USER']}:{os.environ['POSTGRES_PASSWORD']}"
    f"@{os.environ.get('DB_HOST', 'db')}:5432/{os.environ['POSTGRES_DB']}"
)
engine = create_engine(PG_URL, pool_pre_ping=True)


class Base(DeclarativeBase):
    pass


class Visit(Base):
    __tablename__ = "visits"
    id: Mapped[int] = mapped_column(primary_key=True)


# The app owns its schema via its ORM, applied on startup. For real migrations swap in Alembic.
Base.metadata.create_all(engine)

cache = redis.Redis(
    host=os.environ.get("VALKEY_HOST", "valkey"),
    port=6379,
    password=os.environ["VALKEY_PASSWORD"],
    decode_responses=True,
)

app = FastAPI(title="quickstart")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/")
def root():
    with Session(engine) as s:
        s.add(Visit())
        s.commit()
        visits = s.scalar(select(func.count()).select_from(Visit))
    hits = cache.incr("hits")
    return {"hello": "quickstart", "db_visits": visits, "valkey_hits": hits}
