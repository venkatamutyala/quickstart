# Python recipe (FastAPI)

A runnable hello-world: FastAPI + SQLAlchemy (Postgres) + redis (Valkey) + zero-code OTel.

- **ORM / schema:** SQLAlchemy. The stub applies schema on startup via `Base.metadata.create_all`.
  For real migrations, add **Alembic**: `alembic init`, then `make migrate` →
  `docker compose run --rm app alembic upgrade head` (or run it in the entrypoint).
- **OTel (zero-code):** `opentelemetry-instrument uvicorn app:app …` (see Dockerfile). Auto-instruments
  FastAPI, SQLAlchemy, and redis. Driven entirely by the `OTEL_*` env vars; honors `OTEL_SDK_DISABLED`.
  `opentelemetry-bootstrap -a install` (in the build) installs the instrumentation libraries.
- **Deps:** `requirements.txt` (loose major pins). Add libs there; rebuild with `make build`.
- **Config:** env only (`POSTGRES_*`, `DB_HOST`, `VALKEY_*`, `VALKEY_HOST`). Logs to stdout.
- **Port:** 8000.
