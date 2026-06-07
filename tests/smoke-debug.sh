#!/usr/bin/env bash
# Smoke test: the debug box builds and its preloaded CLIs can reach every backend over the
# compose network (run via `make test`). This also validates the wiring the `help`
# cheatsheet documents — the commands below mirror it. Builds the image on first run.
. "$(dirname "$0")/lib.sh"

echo "debug:"

# Run one combined check inside an ephemeral debug container so we build/start it once.
# -T: no TTY (CI). bash -l so the pre-wired env + PATH (kafka-*.sh) are loaded.
docker compose run --rm -T debug bash -lc '
  set -euo pipefail
  psql -tAc "SELECT 1" | grep -qx 1
  aws s3 ls >/dev/null
  [ "$(redis-cli -h cache-valkey ping)" = "PONG" ]
  kcat -b "$KAFKA_BOOTSTRAP" -L >/dev/null
  kafka-topics.sh --bootstrap-server "$KAFKA_BOOTSTRAP" --list >/dev/null
  curl -fsS "$OPENSEARCH_URL/_cluster/health" >/dev/null
  curl -fsS -u "$RABBITMQ_USER:$RABBITMQ_PASSWORD" queue-rabbitmq:15672/api/overview >/dev/null
' && pass "all backend CLIs reachable from debug box" \
  || fail "debug box could not reach one or more backends"
