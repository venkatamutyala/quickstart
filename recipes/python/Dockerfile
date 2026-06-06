FROM python:3.12-slim

# curl is used by the compose healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && opentelemetry-bootstrap -a install

COPY . .
EXPOSE 8000

# Logs go to stdout (uvicorn default). `opentelemetry-instrument` auto-instruments
# FastAPI + SQLAlchemy + redis and exports via the OTEL_* env vars (no-op if OTEL_SDK_DISABLED=true).
CMD ["opentelemetry-instrument", "uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
