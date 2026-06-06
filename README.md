# quickstart

A reusable **GitHub template** for spinning up containerized POCs in minutes — Postgres + Valkey,
GHCR CI, OpenTelemetry/Grafana observability, polyglot service recipes, and optional public
exposure via an SSH tunnel to a bare VPS. Designed to be driven by a human **or** an AI agent
(see [`AGENTS.md`](AGENTS.md)).

## Quickstart (local)
```bash
make init      # generate .env (random secrets) + pgadmin/pgpass
make up        # db + valkey + pgAdmin + Grafana/observability
```
- pgAdmin → http://localhost:8080 (pre-connected to the DB, no password prompt)
- Grafana → http://localhost:3000  (admin / admin)
- Postgres → `127.0.0.1:5432`, Valkey → `127.0.0.1:6379` (creds in `.env`)

`make up-lean` brings up just Postgres + Valkey. `make down` stops everything. `make help` lists all targets.

## Add your service
```bash
make add-service LANG=python NAME=app   # or node / go — all are runnable hello-worlds
```
Then uncomment the `app:` block in `compose.yaml` and `make up`. The hello-world talks to
Postgres (ORM, migrate-on-start) + Valkey and emits traces to Grafana. See [`AGENTS.md`](AGENTS.md)
→ "Add a service".

## Do you need to expose it to the internet?
- **No** → stay on `make up` (everything is on `localhost`). Done.
- **Yes, and you have a bare VPS** (just SSH) → one-time `vps/setup.sh` on the box, then
  `make allow-me && make expose`. You get `https://app.<vps-ip>.sslip.io` with a real Let's Encrypt
  cert, plus raw TCP to Postgres/Valkey — all gated by an IP allowlist. See [`docs/exposure.md`](docs/exposure.md).
- **Yes, but no VPS** → drop in a SaaS tunnel (ngrok/Cloudflare Tunnel) pointed at Traefik, or just
  share `make up` over your LAN.

## How it's built
Convention over generation — no templating engine. The container boundary normalizes languages, so
the repo standardizes the *outside* (compose, Dockerfile contract, `.env`, CI, OTLP, exposure) and
leaves the *inside* (your code) free. Details: [`AGENTS.md`](AGENTS.md) and [`docs/`](docs/).

## Editor compatibility
Claude Code auto-loads `AGENTS.md` via `CLAUDE.md`. Cursor/Copilot read `AGENTS.md` directly. Both
should open the relevant `docs/*.md` per the index in `AGENTS.md`.
