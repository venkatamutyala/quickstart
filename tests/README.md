# Tests

Smoke tests — they boot nothing themselves; they assume the stack is **already running**
(`make up`) and verify each service end-to-end using the same connection details
`make conn` advertises.

## Run them

```bash
make up      # if not already running
make test    # runs every tests/smoke-*.sh
```

CI runs `make test` on every PR (see `.github/workflows/ci.yml`).

## Layout

- `lib.sh` — shared helpers (`pass`/`fail`, loads `.env`, derives the compose network).
- `smoke-<service>.sh` — one per backend. Connects + does a round-trip + asserts; exits
  non-zero on failure.

## Adding a test (one per new backend)

Copy an existing one and keep it self-contained:

```bash
#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
echo "<service>:"
# ...connect using the in-Docker host (e.g. <service>:<port>), do a round-trip...
[ "$result" = "$expected" ] && pass "round-trip" || fail "round-trip"
```

`make test` picks up any `tests/smoke-*.sh` automatically, so CI covers the new service with
no extra wiring. Connect via `docker compose exec` or a throwaway client container on the
compose network (`compose_network`) so the only host dependency stays Docker.

> Plain shell on purpose (lean, FOSS, no toolchain). If per-service tests ever grow large,
> [bats](https://github.com/bats-core/bats-core) (MIT) is the natural upgrade path.
