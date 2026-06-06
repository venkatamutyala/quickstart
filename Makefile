# quickstart — POC starter. Run `make help` for the menu.
.DEFAULT_GOAL := help
.PHONY: help init up up-lean down logs build add-service migrate \
        expose unexpose urls allow deny allow-range allow-me allowed \
        cert-expiry validate-labels debug-expose

# Profiles brought up by `make up` (full local dev). Exposure is opt-in via `make expose`.
DEV_PROFILES := --profile tools --profile observability

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | sort | \
	  awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

init: ## Create .env (random secrets) + pgadmin/pgpass; idempotent (never clobbers .env)
	@if [ -f .env ]; then echo ".env exists — leaving it untouched"; else \
	  cp .env.example .env; \
	  while grep -q '__GEN__' .env; do \
	    sed -i "0,/__GEN__/s//$$(openssl rand -hex 16)/" .env; \
	  done; \
	  echo "generated .env with random secrets"; \
	fi
	@set -a; . ./.env; set +a; \
	  printf 'db:5432:*:%s:%s\n' "$$POSTGRES_USER" "$$POSTGRES_PASSWORD" > pgadmin/pgpass; \
	  chmod 600 pgadmin/pgpass; \
	  echo "wrote pgadmin/pgpass (mode 600)"

up: init ## Start the full local stack (db, valkey, pgadmin, observability); OTEL on
	OTEL_SDK_DISABLED=false docker compose $(DEV_PROFILES) up -d

up-lean: init ## Start core only (db + valkey); no tools/observability; OTEL off
	docker compose up -d

down: ## Stop everything (all profiles)
	docker compose --profile tools --profile observability --profile expose down

logs: ## Tail logs of running services
	docker compose logs -f

build: ## Build local service images
	docker compose build

migrate: ## Run the app's ORM migration (set the command for your ORM)
	@echo "App owns its schema via its ORM (migrate on startup by default)."
	@echo "For an explicit run, e.g.: docker compose run --rm app alembic upgrade head"

add-service: ## Copy a runnable recipe into services/NAME  (make add-service LANG=python NAME=app)
	@test -n "$(LANG)" && test -n "$(NAME)" || { echo "usage: make add-service LANG=python NAME=app"; exit 1; }
	@test -d "recipes/$(LANG)" || { echo "no recipe for LANG=$(LANG) (have: python node go)"; exit 1; }
	mkdir -p services/$(NAME)
	cp -r recipes/$(LANG)/. services/$(NAME)/
	@rm -f services/$(NAME)/service.snippet.yml services/$(NAME)/AGENTS.md
	@echo ""
	@echo "Copied recipes/$(LANG) -> services/$(NAME)."
	@echo "Next: in compose.yaml uncomment the 'app' block (see recipes/$(LANG)/service.snippet.yml),"
	@echo "rename it to '$(NAME)', set build: ./services/$(NAME), then: make up"
	@docker compose config >/dev/null 2>&1 && echo "compose.yaml is valid" || echo "(compose.yaml has no enabled service yet — expected)"

# ---- Exposure (profile: expose) — needs a bare VPS (TUNNEL_* in .env) -------------
SSHV = $$TUNNEL_VPS_USER@$$TUNNEL_VPS_HOST

expose: init ## Expose locally-running services via the SSH tunnel + Traefik (HTTPS)
	@set -a; . ./.env; set +a; \
	  test -n "$$TUNNEL_VPS_HOST" || { echo "set TUNNEL_VPS_HOST + EXPOSE_HOST in .env first"; exit 1; }; \
	  if ssh $(SSHV) "ss -ltnH 'sport = :443' | grep -q ." ; then \
	    echo "VPS :443 is already bound by another tunnel — 'make unexpose' there first"; exit 1; fi; \
	  OTEL_SDK_DISABLED=false COMPOSE_PROFILES=tools,observability,expose docker compose up -d
	@$(MAKE) --no-print-directory urls

unexpose: ## Stop the exposure sidecars (traefik + autossh + socket-proxy)
	docker compose stop traefik autossh dockerproxy

urls: ## Print the public URLs / TCP addresses
	@set -a; . ./.env; set +a; \
	  echo "HTTP : https://app.$$EXPOSE_HOST  (add more via Traefik labels)"; \
	  echo "PG   : psql -h $$TUNNEL_VPS_HOST -p 5432"; \
	  echo "Valkey: redis-cli -h $$TUNNEL_VPS_HOST -p 6379"

allow: ## Allow an IP through the VPS firewall  (make allow IP=1.2.3.4)
	@test -n "$(IP)" || { echo "usage: make allow IP=1.2.3.4"; exit 1; }
	@set -a; . ./.env; set +a; \
	  ssh $(SSHV) "nft add element inet filter allowlist { $(IP) }; \
	    mkdir -p /etc/nftables.d; touch /etc/nftables.d/allowlist.nft; \
	    grep -qF 'allowlist { $(IP) }' /etc/nftables.d/allowlist.nft || \
	    echo 'add element inet filter allowlist { $(IP) }' >> /etc/nftables.d/allowlist.nft"
	@echo "allowed $(IP) (live + persistent)"

allow-range: ## Allow a CIDR  (make allow-range CIDR=203.0.113.0/24)
	@test -n "$(CIDR)" || { echo "usage: make allow-range CIDR=1.2.3.0/24"; exit 1; }
	@set -a; . ./.env; set +a; \
	  ssh $(SSHV) "nft add element inet filter allowlist { $(CIDR) }; \
	    mkdir -p /etc/nftables.d; touch /etc/nftables.d/allowlist.nft; \
	    grep -qF 'allowlist { $(CIDR) }' /etc/nftables.d/allowlist.nft || \
	    echo 'add element inet filter allowlist { $(CIDR) }' >> /etc/nftables.d/allowlist.nft"

allow-me: ## Allow your current public IP
	@set -a; . ./.env; set +a; ME=$$(curl -fsS ifconfig.me); $(MAKE) --no-print-directory allow IP=$$ME

deny: ## Remove an IP from the allowlist  (make deny IP=1.2.3.4)
	@test -n "$(IP)" || { echo "usage: make deny IP=1.2.3.4"; exit 1; }
	@set -a; . ./.env; set +a; \
	  ssh $(SSHV) "nft delete element inet filter allowlist { $(IP) } 2>/dev/null; \
	    sed -i '/allowlist { $(IP) }/d' /etc/nftables.d/allowlist.nft 2>/dev/null || true"
	@echo "denied $(IP)"

allowed: ## List allowlisted IPs on the VPS
	@set -a; . ./.env; set +a; ssh $(SSHV) "nft list set inet filter allowlist"

cert-expiry: ## Days until the Let's Encrypt cert expires
	@docker compose exec traefik sh -c 'apk add --no-cache jq >/dev/null 2>&1; \
	  jq -r ".le.Certificates[].certificate" /letsencrypt/acme.json 2>/dev/null | head -1' \
	  | base64 -d 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null || \
	  echo "no cert yet (run make expose and hit the URL once)"

validate-labels: ## Show how Traefik parsed the current routers (catch label typos)
	@docker compose exec traefik traefik healthcheck >/dev/null 2>&1 || true
	@docker compose logs traefik | grep -iE "error|router|rule" | tail -20

debug-expose: ## Tunnel + cert + route health summary
	@docker compose ps traefik autossh dockerproxy
	@$(MAKE) --no-print-directory cert-expiry
