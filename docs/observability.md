# Observability (OpenTelemetry + Grafana)

`make up` starts `grafana/otel-lgtm` (Loki, Grafana, Tempo, Prometheus, Pyroscope in one container,
dev-only). Grafana: http://localhost:3000 (admin/admin), with datasources pre-wired.

## The contract (language-agnostic)
Services export OTLP using standard env vars (in `.env`):
```
OTEL_EXPORTER_OTLP_ENDPOINT=http://lgtm:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_SERVICE_NAME=poc-app
OTEL_TRACES_EXPORTER=otlp   # + METRICS/LOGS
OTEL_SDK_DISABLED=true      # see below
```
- **`OTEL_SDK_DISABLED` defaults to `true`** so `make up-lean` (no collector) never hangs on export
  retries. `make up` sets it to `false`. Per-service, the compose block uses
  `OTEL_SDK_DISABLED: ${OTEL_SDK_DISABLED:-true}` so the `make up` override flows through.

## Per-language instrumentation (zero-code where possible)
- **Python:** `opentelemetry-instrument uvicorn app:app` (+ `opentelemetry-bootstrap -a install` at build).
- **Node:** `node --require @opentelemetry/auto-instrumentations-node/register app.js`.
- **Go:** set up the OTel SDK in code (no zero-code agent) — gate it on `OTEL_SDK_DISABLED`.

## Two producers feed Grafana
1. Your app (via the env above).
2. **Traefik itself** — its native OTLP metrics+tracing point at `lgtm`, so ingress request
   rates/latencies/traces appear even before you instrument an app.

Persistence: the `lgtm-data` named volume keeps dashboards/data across `make down`. For production,
swap `OTEL_EXPORTER_OTLP_ENDPOINT` to Grafana Cloud / your vendor — the app code doesn't change.
