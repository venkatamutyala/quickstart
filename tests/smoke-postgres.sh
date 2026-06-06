#!/usr/bin/env bash
# Smoke test: Postgres is up and accepts queries (run via `make test`).
. "$(dirname "$0")/lib.sh"

echo "postgres:"
pg() { docker compose exec -T db-postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA "$@"; }

pg -c 'SELECT 1' | grep -qx 1 && pass "connect + SELECT 1" || fail "connect + SELECT 1"

out="$(pg -c 'CREATE TEMP TABLE smoke(x int); INSERT INTO smoke VALUES (42); SELECT x FROM smoke;')"
# psql echoes command tags (CREATE TABLE / INSERT 0 1); the queried value is its own line.
printf '%s\n' "$out" | grep -qx 42 && pass "temp-table round-trip" || fail "temp-table round-trip (got: $out)"
