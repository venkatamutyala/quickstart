.DEFAULT_GOAL := help
SHELL := /bin/bash

# Load .env (if present) so url/psql/info can read the values.
ifneq (,$(wildcard .env))
include .env
endif

.PHONY: help init up down reset url conn env example psql info status logs test version garage-init tunnel tunnel-login

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(firstword $(MAKEFILE_LIST)) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-13s\033[0m %s\n", $$1, $$2}'

init: ## Create .env from .env.example (won't overwrite an existing one)
	@if [ -f .env ]; then \
		echo ".env already exists — leaving it untouched."; \
	else \
		cp .env.example .env && echo "Created .env (edit it to taste, then 'make up')."; \
	fi

up: _require-env _render ## Start everything (Postgres, Garage, Valkey, RabbitMQ + UIs) and init S3
	docker compose up -d --wait db-postgres pgadmin s3-garage s3-garage-ui cache-valkey cache-valkey-ui queue-rabbitmq
	@$(MAKE) --no-print-directory garage-init
	@$(MAKE) --no-print-directory info

garage-init: _require-env ## Initialize Garage cluster, key, and bucket (idempotent)
	@./scripts/garage-init.sh

down: ## Stop the stack (keeps data)
	docker compose down

reset: ## Stop and DELETE the data volume (fresh database next 'up')
	docker compose down --volumes

url: _require-env ## Print the connection string for your app
	@echo "postgresql://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@localhost:$(PGPORT)/$(POSTGRES_DB)?sslmode=disable"

conn: _require-env ## Print broken-out connection details (ONLY=postgres|s3|valkey|rabbitmq)
	@./scripts/conn.sh $(ONLY)

env: _require-env ## Print eval-able env exports for your app:  eval "$$(make env)"
	@./scripts/print-env.sh

example: _require-env ## Run the example app (Postgres + S3) against the running stack
	docker run --rm --network "$$(basename "$$PWD" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')_default" \
		-e DATABASE_URL="postgresql://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@db-postgres:5432/$(POSTGRES_DB)?sslmode=disable" \
		-e AWS_ACCESS_KEY_ID="$(GARAGE_ACCESS_KEY_ID)" -e AWS_SECRET_ACCESS_KEY="$(GARAGE_SECRET_ACCESS_KEY)" \
		-e AWS_REGION="$(GARAGE_REGION)" -e AWS_ENDPOINT_URL="http://s3-garage:3900" -e S3_BUCKET="$(GARAGE_BUCKET)" \
		-v "$$PWD/examples/python:/app:ro" -w /app python:3.12 \
		sh -c "pip install -q -r requirements.txt && python main.py"

psql: _require-env ## Open a psql shell inside the db container
	docker compose exec db-postgres psql -U "$(POSTGRES_USER)" -d "$(POSTGRES_DB)"

version: ## Print the current version (git tag)
	@git describe --tags --always --dirty 2>/dev/null || echo "(no release tag yet)"

info: _require-env ## Show URLs and credentials for this instance
	@printf 'Version   : %s\n' "$$(git describe --tags --always --dirty 2>/dev/null || echo 'dev (no tag)')"
	@echo "Postgres  : postgresql://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@localhost:$(PGPORT)/$(POSTGRES_DB)?sslmode=disable"
	@echo "pgAdmin   : http://localhost:$(PGADMIN_PORT)  ($(PGADMIN_EMAIL) / $(PGADMIN_PASSWORD))"
	@echo "S3 (Garage): http://localhost:$(GARAGE_S3_PORT)  (region $(GARAGE_REGION), bucket $(GARAGE_BUCKET))"
	@echo "Garage UI : http://localhost:$(GARAGE_UI_PORT)"
	@echo "Valkey    : redis://default:$(VALKEY_PASSWORD)@localhost:$(VALKEY_PORT)/0  (UI http://localhost:$(VALKEY_UI_PORT))"
	@echo "RabbitMQ  : amqp://$(RABBITMQ_USER):$(RABBITMQ_PASSWORD)@localhost:$(RABBITMQ_PORT)/  (UI http://localhost:$(RABBITMQ_MANAGEMENT_PORT))"
	@echo "Run 'make conn' for full per-service connection details."

status: _require-env ## Show live container status/health
	docker compose ps

test: _require-env ## Run smoke tests against the running stack (run 'make up' first)
	@for t in tests/smoke-*.sh; do echo "▶ $$t"; bash "$$t" || exit 1; done
	@echo "All smoke tests passed."

logs: ## Tail logs — all services, or one via SVC=db-postgres
	docker compose logs -f $(SVC)

tunnel-login: ## Log in to dev tunnels with GitHub (device-code; headless-friendly)
	devtunnel user login --github --use-device-code-auth

tunnel: _require-env ## Expose the GUIs (pgAdmin + Garage UI) via a dev tunnel (ANON=1 for anonymous)
	@./scripts/tunnel.sh

# --- internal helpers ---

_require-env:
	@test -f .env || { echo "No .env found. Run 'make init' first."; exit 1; }

# Render config that embeds .env values, so .env stays the single source of truth.
_render:
	@sed "s|__POSTGRES_USER__|$(POSTGRES_USER)|g" pgadmin/servers.json.tmpl > pgadmin/servers.json
	@printf 'db-postgres:5432:*:%s:%s\n' "$(POSTGRES_USER)" "$(POSTGRES_PASSWORD)" > pgadmin/pgpass
	@chmod 600 pgadmin/pgpass
	@sed "s|__GARAGE_REGION__|$(GARAGE_REGION)|g" garage/garage.toml.tmpl > garage/garage.toml
