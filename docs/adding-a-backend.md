# Adding a backend

Every backend in this stack follows **one repeatable pattern**. Copy it and the new
service automatically gets the same developer experience: one-command `make up`, a UI,
`make conn` details (host + in-Docker), enforced secrets, and pinned images.

`db-postgres` and `s3-garage` are the two reference implementations — read them next to
this guide.

## The pattern at a glance

A backend =
**a service** (+ optional **`<service>-ui`**) + **an `.env` block** + **a `conn.sh`
section** + (only if it needs first-run setup) **an idempotent `scripts/<name>-init.sh`**.

Everything reads from `.env` (the single source of truth), real secrets are enforced, and
images are pinned by digest.

## Conventions

- **FOSS only.** Use the upstream/official image, never a vendor "community edition"
  (e.g. `apache/kafka`, not `confluentinc/cp-kafka`; `valkey`, not non-FOSS Redis).
- **Data backends only.** Databases, object storage, queues/brokers, caches, search. This
  is **not** an AWS/cloud emulator — no Lambda/IAM/etc.
- **Single-node, plaintext, local-only.** No clustering, TLS, or prod hardening.
- **Service name = in-Docker hostname.** Use `<category>-<impl>`: `db-postgres`,
  `s3-garage`, and for new ones `cache-valkey`, `queue-rabbitmq`, `stream-kafka`. UI service
  is `<service>-ui`.

## Steps

### 1. Pick a FOSS image and pin it by digest
```bash
docker pull <image>:<tag>
docker image inspect <image>:<tag> --format '{{index .RepoDigests 0}}'
```
Use `image: <image>:<tag>@sha256:...` so the tag stays readable and the bits are immutable.

### 2. Add an `.env` block (`.env.example`)
Group with a header; provide local-dev defaults:
```dotenv
# --- valkey (cache) ---
VALKEY_PASSWORD=valkey
VALKEY_PORT=6379
```
- Mark which values are **secrets** (enforced in step 3) vs plain config.
- If a value must match something inside a config file (like Garage's `s3_region`), say so
  in a comment so the two don't drift.

### 3. Add the service to `docker-compose.yaml`
- `image:` pinned by digest.
- `environment:` from `.env`. Wrap **every real secret** in
  `${VAR:?missing — run 'make init' to create .env from .env.example}` so the stack refuses
  to start without it. Non-secrets use `${VAR:-default}`.
- `volumes:` a named volume for persistent data (also add it to the top-level `volumes:`).
- `ports:` `"${X_PORT:-<default>}:<internal>"`.
- `healthcheck:` `CMD-SHELL` if the image has a shell; exec-form `CMD ["bin","arg"]` if it's
  distroless (Garage is — copy that pattern).
- UI (if any): add `<svc>-ui` with
  `depends_on: { <svc>: { condition: service_healthy } }` and point it at the service over
  the compose network (`http://<svc>:<port>`).

### 4. First-run setup — only if needed
If the backend needs initialization beyond "start" (Garage needs a layout + key + bucket),
add `scripts/<name>-init.sh`:
- Source `.env` (`set -a; . ./.env; set +a`) and guard the secrets it uses:
  `: "${VAR:?missing in .env — run 'make init'}"`.
- Make it **idempotent** (check-before-create) — it runs on every `make up`.
- Call it from the Makefile `up` target (see how `garage-init` is wired).

### 5. Add a `conn.sh` section
In `scripts/conn.sh`, add `if want <name>; then ... fi` printing, with live `.env` values:
- the broken-out fields (host, port, creds, …),
- **both** assembled forms — "From your host" (`localhost:<published>`) and "From inside
  Docker" (`<service>:<internal>`),
- the client options/gotchas that matter (TLS off, auth, any required flags).

Keep it **generic** — no per-language code snippets (that matrix is unmaintainable).

### 6. Wire up the Makefile
- Add the service to the `up` service list.
- Add a line to `info`.
- Add a `<name>-init` target if you wrote an init script (and call it from `up`).
- Reuse the generic `conn` / `logs` / `status` — avoid per-service commands.

### 7. Generated / secret files
If you render a config from `.env` (like `servers.json` / `garage.toml` in `_render`), do it
in a Makefile helper and add the output path to `.gitignore`.

### 8. Add a smoke test, then verify
Create `tests/smoke-<name>.sh` (copy `tests/smoke-postgres.sh`): source `tests/lib.sh`,
connect using the in-Docker details, do a round-trip, and `pass`/`fail`. `make test` runs
every `tests/smoke-*.sh` and CI runs `make test` on every PR — so your service is covered
automatically. See [tests/README.md](../tests/README.md). Then:
```bash
make reset && make up          # fresh
make test                      # your new smoke test runs too
make conn ONLY=<name>          # details look right
make status                    # all services healthy
```

### 9. Add it to the debug box
The `debug` service (`make debug`) bundles every backend's native CLI, pre-wired to the
stack. Keep it complete for your new backend:
- Install the client CLI in `debug/Dockerfile` (apt where possible; checksum-verify any
  downloaded binary, like the Kafka tools / `mc` already do).
- Add the wiring to the `debug` service `environment:` in `docker-compose.yaml` — use the
  in-Docker hostname and pull secrets from `.env` via `${VAR:?...}` (never hardcode).
- Add a one- or two-line entry to `debug/quickstart-help.sh` (the `help` cheatsheet).
- Add an assertion to `tests/smoke-debug.sh` so CI verifies the CLI can reach your backend.

### 10. Document
- Add the service to the README service list.
- No changelog edit needed — it's generated from your Conventional Commit message.

## Worked sketch — Valkey (illustrative)

`.env.example`:
```dotenv
# --- valkey (cache) ---
VALKEY_PASSWORD=valkey
VALKEY_PORT=6379
```
`docker-compose.yaml`:
```yaml
  cache-valkey:
    image: valkey/valkey:8@sha256:...           # pin the real digest
    command: ["valkey-server", "--requirepass", "${VALKEY_PASSWORD:?missing — run 'make init'}"]
    ports:
      - "${VALKEY_PORT:-6379}:6379"
    volumes:
      - valkeydata:/data
    healthcheck:
      test: ["CMD", "valkey-cli", "-a", "${VALKEY_PASSWORD}", "ping"]
      interval: 5s
      timeout: 3s
      retries: 12
```
`scripts/conn.sh` (new `want valkey` section) prints, e.g.:
```
  Host (host)      : localhost:6379           URL: redis://default:valkey@localhost:6379/0
  Host (in-Docker) : cache-valkey:6379        URL: redis://default:valkey@cache-valkey:6379/0
  Note             : Valkey speaks the Redis protocol — any redis:// client works.
```
A FOSS web UI is optional (e.g. `redis-commander`, MIT). No first-run init script is needed.
