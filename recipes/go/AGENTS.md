# Go recipe — agent notes

Minimal hello-world: `net/http` + `jackc/pgx` (Postgres) + `redis/go-redis` (Valkey) + OpenTelemetry.
All config is via env (see compose `.env`); logs go to stdout. The HTTP server listens on `:8000`
with `GET /health` and `GET /` (insert+count a `visits` row, INCR a `hits` key).

## Schema / ORM
The stub uses raw SQL (`CREATE TABLE IF NOT EXISTS visits ...`) applied on startup so it is
self-contained. For a real app, pick one:
- **sqlc** (type-safe queries from SQL) + a migration tool, or
- **GORM** (`gorm.io/gorm` + `gorm.io/driver/postgres`) with `db.AutoMigrate(&Visit{})`.
The app owns its schema and applies it on startup — do not put migrations in `db/init/`
(that dir is first-boot bootstrap only).

## Migrations
Recommended: **golang-migrate**. Install + run:
```
go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
migrate -path ./migrations -database "$DATABASE_URL" up
```
(Atlas — `atlas migrate apply --url "$DATABASE_URL"` — is a good declarative alternative.)

## OpenTelemetry
Go has **no zero-code agent**, so the SDK is wired in `main.go` (`initTracer`) and gated by
`OTEL_SDK_DISABLED`. One-liner contract: it reads `OTEL_EXPORTER_OTLP_ENDPOINT` /
`OTEL_SERVICE_NAME` / `OTEL_RESOURCE_ATTRIBUTES`, exports OTLP/HTTP, and is a no-op when
`OTEL_SDK_DISABLED=true`. `otelhttp.NewHandler` makes each request a server span.

## Deps / build
- `go.mod` pins module versions; refresh with `go get <mod>@<ver> && go mod tidy`.
- Build locally: `go build .`  ·  run: `go run .`
- Container: multi-stage Dockerfile builds a static binary (`CGO_ENABLED=0`) into `alpine:3.20`.
  The final image includes `wget` so the compose healthcheck (`wget -qO- .../health`) works.
