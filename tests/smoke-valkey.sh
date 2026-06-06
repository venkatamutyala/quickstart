#!/usr/bin/env bash
# Smoke test: Valkey authenticates and does a set/get round-trip (run via `make test`).
. "$(dirname "$0")/lib.sh"

echo "valkey (cache):"
# --no-auth-warning keeps the password off stderr; valkey-cli ships in the image.
vk() { docker compose exec -T cache-valkey valkey-cli -a "$VALKEY_PASSWORD" --no-auth-warning "$@"; }

[ "$(vk ping)" = "PONG" ] && pass "auth + PING" || fail "auth + PING"

marker="smoke-${RANDOM}${RANDOM}"
vk set smoke:key "$marker" >/dev/null
got="$(vk get smoke:key)"
vk del smoke:key >/dev/null
[ "$got" = "$marker" ] && pass "set/get round-trip" || fail "set/get round-trip (got: $got)"
