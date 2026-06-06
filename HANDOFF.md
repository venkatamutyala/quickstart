# HANDOFF — quickstart POC starter

> Session-state note so work can resume in a fresh session. **Transient** — delete once the template
> is finalized. Source of truth for the stack is `AGENTS.md` + `docs/`.

- **Date:** 2026-06-06
- **Repo:** https://github.com/venkatamutyala/quickstart  ·  local dir `/workspaces/glueops/poc-mode`
- **Branch:** `feat/quickstart-poc-starter` (commit `1f5cc89`, pushed; `main` untouched, no PR opened yet)

## What this is
A reusable **GitHub-template** repo for spinning up containerized POCs fast — usable by a human or an
AI agent. Philosophy: *standardize the outside* (compose, Dockerfile, `.env`, GHCR CI, OTLP, exposure),
leave the language inside free. No templating engine.

## Locked decisions (don't relitigate)
- Postgres + Valkey core; **ORM owns schema** (migrate-on-start, no Flyway); `db/init/` = bootstrap only.
- 12-factor, **stdout logging**, OTel/Grafana (`grafana/otel-lgtm`) on by default; Traefik also emits OTLP.
- Secrets: `.env.example` → gitignored `.env` via idempotent `make init`; deployed secrets via GitHub.
- `services/app` is an **empty placeholder**; `recipes/{python,node,go}/` are **runnable** hello-worlds
  you copy with `make add-service`.
- **Exposure (opt-in, dev-only):** local **Traefik** ingress (label discovery) + **native SSH reverse
  tunnel** to a **bare root-SSH VPS** (only sshd + nftables). **sslip.io + Let's Encrypt (TLS-ALPN-01)**,
  no domain needed. **No OAuth** — access gated by an **nftables IP allowlist** on the VPS
  (`make allow/deny/allow-me`). Self-owned infra preferred over SaaS.

## Status — DONE & locally verified
- **Phase 0:** compose.yaml (creds externalized), .gitignore, flyway removed, pgAdmin auto-connects via
  PassFile/pgpass (the old bug — fixed), db/valkey healthchecks. pgpass untracked from git.
- **Phase 1:** Valkey + compose profiles (tools/observability/expose), `make init` (idempotent, secrets,
  pgpass 600), full Makefile, layered docs (`AGENTS.md` 51 lines + `CLAUDE.md` + `README.md` + `docs/*`).
- **Phase 2:** runnable recipes python/node/go (each verified: build → `/health` → Postgres+Valkey
  counters → **OTLP traces in Tempo**), `make add-service`, GHCR `build.yml` (auto-discovers services).
- **Phase 3:** Traefik **v3.7** ingress + read-only docker-socket-proxy (label routing proven), autossh
  reverse-tunnel service, `vps/setup.sh` + `vps/nftables.conf`, `make expose/unexpose/urls/allow*/cert-expiry`.

Verified with real `docker compose`: `make up` (all healthy, Grafana 200, pgAdmin no prompt), all 3
recipes, Traefik routing (`Host:` → backend; unknown → 404), `make add-service` → `make up` app healthy.

## Remaining (NEEDS A LIVE VPS — could not test headlessly)
1. The SSH tunnel, real Let's Encrypt issuance, and the nftables allowlist. To run:
   - In `.env`: `TUNNEL_VPS_HOST=<vps-ip>`, `EXPOSE_HOST=<vps-ip-dashed>.sslip.io`; SSH key in ssh-agent.
   - `scp -r vps/ root@<vps-ip>:/root/qs-vps && ssh root@<vps-ip> 'bash /root/qs-vps/setup.sh'`
   - `make allow-me && make expose` → check `https://app.$EXPOSE_HOST` (green LE cert), `psql -h <vps> -p 5432`,
     `redis-cli -h <vps> -p 6379`, and that a non-allowlisted IP is refused. See `docs/exposure.md`.
2. Then: open the PR and mark the repo as a **GitHub Template** (Settings → Template repository).

## Gotchas already handled
- **Traefik must be ≥ v3.7** — older defaults to Docker API v1.24, rejected by Docker 25+ (min 1.40).
- This devcontainer's **port 8000 is taken by `code-tunnel`** — recipes still default to 8000 (fine
  elsewhere); was tested on 8009.
- `make init` keeps `.env` comments on their own lines (some tools fold trailing `# ...` into values).

## To resume
The approved plan was at `~/.claude/plans/i-m-trying-to-make-mossy-milner.md` and a memory at
`~/.claude/projects/.../memory/poc-infra-preferences.md` — these may NOT survive a session wipe; this
file + the repo are the durable record. Paste the resume prompt from the chat (or below).

### Resume prompt
```
Resume the `quickstart` POC starter template in /workspaces/glueops/poc-mode
(repo github.com/venkatamutyala/quickstart, branch feat/quickstart-poc-starter).
Read HANDOFF.md, AGENTS.md, and docs/ first. Phases 0-3 are built and locally
verified (core stack, python/node/go recipes, Traefik routing, GHCR CI). The
only untested part is the exposure layer, which needs my VPS. Help me: (1) set
TUNNEL_VPS_HOST + EXPOSE_HOST in .env, run vps/setup.sh on the box, then
`make allow-me && make expose`, and verify HTTPS via sslip.io + raw TCP to
Postgres/Valkey + the nftables allowlist refusing non-allowlisted IPs; (2) then
open the PR and mark the repo as a GitHub Template. Note: Traefik must be v3.7+
for Docker 29; this devcontainer's port 8000 is used by code-tunnel.
```
