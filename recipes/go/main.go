// Runnable hello-world: HTTP + Postgres (schema-on-start) + Valkey cache + OTLP.
//
// This is the copyable reference for the quickstart stack. 12-factor: all config via env,
// logs to stdout. Unlike Python/Node, Go has no zero-code agent, so OpenTelemetry is wired
// up here in code and gated by OTEL_SDK_DISABLED (true=off) — see initTracer below.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

// env returns the value of key, or def when unset/empty.
func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// initTracer configures an OTLP/HTTP trace exporter from the OTEL_* env vars and
// returns a shutdown func. It is a no-op when OTEL_SDK_DISABLED=true, honoring the
// same contract as the auto-instrumented recipes.
func initTracer(ctx context.Context) (func(context.Context) error, error) {
	if env("OTEL_SDK_DISABLED", "false") == "true" {
		log.Println("OTEL_SDK_DISABLED=true: tracing off")
		return func(context.Context) error { return nil }, nil
	}

	// otlptracehttp reads OTEL_EXPORTER_OTLP_ENDPOINT / *_PROTOCOL automatically.
	exporter, err := otlptracehttp.New(ctx)
	if err != nil {
		return nil, fmt.Errorf("otlp exporter: %w", err)
	}

	// Service name resolution mirrors the SDK spec: OTEL_SERVICE_NAME wins, else the
	// service.name in OTEL_RESOURCE_ATTRIBUTES, else a sane default. resource.New merges
	// in OTEL_RESOURCE_ATTRIBUTES for us.
	res, err := resource.New(ctx,
		resource.WithFromEnv(),
		resource.WithAttributes(semconv.ServiceName(env("OTEL_SERVICE_NAME", "quickstart-go"))),
	)
	if err != nil {
		return nil, fmt.Errorf("otel resource: %w", err)
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)
	log.Println("OpenTelemetry tracing enabled, exporting to", env("OTEL_EXPORTER_OTLP_ENDPOINT", "(default)"))
	return tp.Shutdown, nil
}

func main() {
	ctx := context.Background()

	shutdown, err := initTracer(ctx)
	if err != nil {
		log.Fatalf("init tracer: %v", err)
	}
	defer func() { _ = shutdown(context.Background()) }()

	// --- Postgres ---
	pgURL := fmt.Sprintf("postgres://%s:%s@%s:5432/%s",
		os.Getenv("POSTGRES_USER"),
		os.Getenv("POSTGRES_PASSWORD"),
		env("DB_HOST", "db"),
		os.Getenv("POSTGRES_DB"),
	)
	pool, err := pgxpool.New(ctx, pgURL)
	if err != nil {
		log.Fatalf("connect postgres: %v", err)
	}
	defer pool.Close()

	// The app owns its schema, applied on startup. CREATE TABLE IF NOT EXISTS keeps the
	// stub self-contained; for real migrations use sqlc/Atlas (see AGENTS.md).
	if _, err := pool.Exec(ctx,
		`CREATE TABLE IF NOT EXISTS visits (id SERIAL PRIMARY KEY)`); err != nil {
		log.Fatalf("create schema: %v", err)
	}

	// --- Valkey (Redis protocol) ---
	cache := redis.NewClient(&redis.Options{
		Addr:     fmt.Sprintf("%s:6379", env("VALKEY_HOST", "valkey")),
		Password: os.Getenv("VALKEY_PASSWORD"),
	})
	defer cache.Close()

	mux := http.NewServeMux()

	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, map[string]any{"status": "ok"})
	})

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()

		if _, err := pool.Exec(ctx, `INSERT INTO visits DEFAULT VALUES`); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		var visits int64
		if err := pool.QueryRow(ctx, `SELECT count(*) FROM visits`).Scan(&visits); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		hits, err := cache.Incr(ctx, "hits").Result()
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		writeJSON(w, map[string]any{
			"hello":       "quickstart",
			"db_visits":   visits,
			"valkey_hits": hits,
		})
	})

	// otelhttp wraps the mux so each request becomes a server span (no-op when disabled).
	handler := otelhttp.NewHandler(mux, "http.server")

	srv := &http.Server{
		Addr:              ":8000",
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
	}
	log.Println("listening on :8000")
	if err := srv.ListenAndServe(); err != nil {
		log.Fatalf("server: %v", err)
	}
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(v)
}
