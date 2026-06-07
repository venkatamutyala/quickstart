.DEFAULT_GOAL := help
SHELL := /bin/bash

# Load .env (if present) so conn/info/env can read the values.
ifneq (,$(wildcard .env))
include .env
endif

.PHONY: help init up down reset conn ai env info status logs test tunnel tunnel-login debug debug-build

##@ Core
help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} \
		/^##@ / {printf "\n\033[1m%s\033[0m\n", substr($$0, 5); next} \
		/^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-13s\033[0m %s\n", $$1, $$2}' $(firstword $(MAKEFILE_LIST))

init: ## Create .env from .env.example (won't overwrite an existing one)
	@if [ -f .env ]; then \
		echo ".env already exists — leaving it untouched."; \
	else \
		cp .env.example .env && echo "Created .env (edit it to taste, then 'make up')."; \
	fi

up: _require-env _render ## Start everything (Postgres, Garage, Valkey, RabbitMQ, Kafka, OpenSearch + UIs), init S3 (+ any Kafka topics)
	docker compose up -d --wait db-postgres pgadmin s3-garage s3-garage-ui cache-valkey cache-valkey-ui queue-rabbitmq stream-kafka stream-kafka-ui search-opensearch search-opensearch-ui
	@$(MAKE) --no-print-directory _garage-init
	@$(MAKE) --no-print-directory _kafka-init
	@$(MAKE) --no-print-directory info

down: ## Stop the stack (keeps data)
	docker compose down

reset: ## Stop and DELETE the data volume (fresh database next 'up')
	docker compose down --volumes

conn: _require-env ## Print broken-out connection details (ONLY=postgres|s3|valkey|rabbitmq|kafka|opensearch)
	@./scripts/conn.sh $(ONLY)

ai: _require-env ## Print AI-handoff text to append to another assistant's prompt (menu of running backends)
	@./scripts/ai.sh

##@ Introspect
info: _require-env ## Show URLs and credentials for this instance
	@printf 'Version   : %s\n' "$$(git describe --tags --always --dirty 2>/dev/null || echo 'dev (no tag)')"
	@echo "Postgres  : postgresql://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@localhost:$(PGPORT)/$(POSTGRES_DB)?sslmode=disable"
	@echo "pgAdmin   : http://localhost:$(PGADMIN_PORT)  (opens straight in — no login, Postgres pre-connected)"
	@echo "S3 (Garage): http://localhost:$(GARAGE_S3_PORT)  (region $(GARAGE_REGION), bucket $(GARAGE_BUCKET))"
	@echo "Garage UI : http://localhost:$(GARAGE_UI_PORT)  (opens straight in — no login)"
	@echo "Valkey    : redis://default:$(VALKEY_PASSWORD)@localhost:$(VALKEY_PORT)/0  (UI http://localhost:$(VALKEY_UI_PORT) — no login)"
	@echo "RabbitMQ  : amqp://$(RABBITMQ_USER):$(RABBITMQ_PASSWORD)@localhost:$(RABBITMQ_PORT)/  (UI http://localhost:$(RABBITMQ_MANAGEMENT_PORT) — log in: $(RABBITMQ_USER) / $(RABBITMQ_PASSWORD))"
	@echo "Kafka     : localhost:$(KAFKA_PORT)  (PLAINTEXT, no auth; UI http://localhost:$(KAFKA_UI_PORT) — no login)"
	@echo "OpenSearch: http://localhost:$(OPENSEARCH_PORT)  (no auth; Dashboards http://localhost:$(OPENSEARCH_DASHBOARDS_PORT) — no login)"
	@echo "Run 'make conn' for full per-service connection details."

env: _require-env ## Print eval-able env exports for your app:  eval "$$(make env)"
	@./scripts/print-env.sh

status: _require-env ## Show live container status/health
	docker compose ps

logs: ## Tail logs — all services, or one via SVC=db-postgres
	docker compose logs -f $(SVC)

##@ Advanced
debug: _require-env ## Shell with every backend CLI preloaded & wired (run 'make up' first; CMD='aws s3 ls' for a one-off)
	@QS_CMD='$(value CMD)'; \
	if [ -n "$$QS_CMD" ]; then docker compose run --rm debug bash -lc "$$QS_CMD"; \
	else docker compose run --rm debug; fi

debug-build: ## (Re)build the debug image after editing debug/Dockerfile
	docker compose build debug

test: _require-env ## Run smoke tests against the running stack (run 'make up' first)
	@for t in tests/smoke-*.sh; do echo "▶ $$t"; bash "$$t" || exit 1; done
	@echo "All smoke tests passed."

tunnel-login: ## Log in to dev tunnels with GitHub (device-code; headless-friendly)
	devtunnel user login --github --use-device-code-auth

tunnel: _require-env ## Expose all GUIs (pgAdmin, Garage, Valkey, RabbitMQ, Kafka, OpenSearch) via a dev tunnel (ANON=1 for anonymous)
	@./scripts/tunnel.sh

# --- internal helpers (hidden from `make help`) ---

_require-env:
	@test -f .env || { echo "No .env found. Run 'make init' first."; exit 1; }

# Garage needs a one-time cluster layout + key + bucket; idempotent, run by `up`.
_garage-init: _require-env
	@./scripts/garage-init.sh

# Create the topics declared in KAFKA_TOPICS; idempotent, run by `up`.
_kafka-init: _require-env
	@./scripts/kafka-init.sh

# Render config that embeds .env values, so .env stays the single source of truth.
_render:
	@sed "s|__POSTGRES_USER__|$(POSTGRES_USER)|g" pgadmin/servers.json.tmpl > pgadmin/servers.json
	@sed "s|__GARAGE_REGION__|$(GARAGE_REGION)|g" garage/garage.toml.tmpl > garage/garage.toml
