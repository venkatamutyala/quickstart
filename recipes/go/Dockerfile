# --- build stage -------------------------------------------------------------
FROM golang:1.23-alpine AS build
WORKDIR /src

# Cache deps first: only re-download when go.mod/go.sum change.
COPY go.mod go.sum ./
RUN go mod download

COPY . .
# Static binary so it runs on a minimal final image.
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /app .

# --- final stage -------------------------------------------------------------
# Alpine (not scratch) so the compose healthcheck has a shell + wget available.
FROM alpine:3.20
RUN apk add --no-cache wget ca-certificates
WORKDIR /app
COPY --from=build /app /app/app
EXPOSE 8000

# Logs go to stdout (Go's log package default). OpenTelemetry is wired in code and
# gated by OTEL_SDK_DISABLED (true=off) — Go has no zero-code auto-instrumentation agent.
ENTRYPOINT ["/app/app"]
