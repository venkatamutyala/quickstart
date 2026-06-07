#!/usr/bin/env bash
# Smoke test: OpenSearch — index a document, read it back, then delete the index (run via
# `make test`). Runs curl inside the container via `docker compose exec` (the image ships
# curl), so the only host dependency stays "Docker".
. "$(dirname "$0")/lib.sh"

echo "opensearch (search):"
index="smoke-${RANDOM}${RANDOM}"
marker="smoke-${RANDOM}"
# -s stays quiet; we assert on the body. Security is disabled, so no auth/TLS.
os() { docker compose exec -T search-opensearch curl -sS -H 'content-type: application/json' "$@"; }
base="http://localhost:9200"

# Cluster answers (green on boot; yellow once a default-replica index exists — both pass).
os "$base/_cluster/health" | grep -q '"status"' && pass "cluster health" || fail "cluster health"

# Index one doc with refresh so it's immediately searchable, read it back by id, then clean up.
os -X PUT "$base/$index/_doc/1?refresh=true" -d "{\"marker\":\"$marker\"}" >/dev/null \
  && pass "index document" || fail "index document"

# `|| true`: on a real read-back failure grep exits 1 — don't let that trip `set -e`
# inside the substitution, so the cleanup and labeled fail() below still run.
got="$(os "$base/$index/_doc/1" | grep -o "$marker" | head -1 || true)"
os -X DELETE "$base/$index" >/dev/null 2>&1 || true

[ "$got" = "$marker" ] && pass "get round-trip" || fail "get round-trip (got: $got)"
