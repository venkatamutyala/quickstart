# Node recipe (Express + Postgres + Valkey + OpenTelemetry)

Runnable hello-world mirroring the quickstart contract. CommonJS, Node 22.
HTTP on :8000 — `GET /health` -> `{"status":"ok"}`; `GET /` inserts a `visits`
row, counts rows, `INCR`s a `hits` key in Valkey, returns
`{"hello":"quickstart","db_visits":N,"valkey_hits":M}`.

## Config (env only, logs to stdout)
`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `DB_HOST` (default `db`),
`VALKEY_PASSWORD`, `VALKEY_HOST` (default `valkey`, port 6379).

## ORM + migrations
The stub uses node-postgres (`pg`) with `CREATE TABLE IF NOT EXISTS` so the app
owns its schema, applied on startup. For real projects use **Prisma**:
- Define models in `prisma/schema.prisma`.
- Migrate (dev): `npx prisma migrate dev --name init`
- Apply in prod/CI: `npx prisma migrate deploy`
- Generate client: `npx prisma generate` (run in the build stage).
Run `migrate deploy` on container start (entrypoint) or as a one-shot job before
the app boots — never auto-create against a shared DB without migrations.

## OpenTelemetry (zero-code)
Auto-instrumentation via the run flag — no SDK code in `app.js`:
`node --require @opentelemetry/auto-instrumentations-node/register app.js`
It instruments http/express + pg + redis and exports OTLP/HTTP to
`OTEL_EXPORTER_OTLP_ENDPOINT` (e.g. `http://lgtm:4318`). `OTEL_SDK_DISABLED=true`
turns it fully off (default in `.env`; `make up` sets `false`).

## Deps / build
- Manifest: `package.json` (express, pg, redis, @opentelemetry/auto-instrumentations-node).
- `npm install --omit=dev` in a multi-stage Dockerfile; runtime image installs
  `curl` for the compose healthcheck (`GET /health`).
- Build: `docker build -t app ./recipes/node`. Local port: `127.0.0.1:8000:8000`.
