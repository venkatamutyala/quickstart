#!/usr/bin/env bash
# Smoke test: Kafka — create an ephemeral topic, produce a message, consume it back, then
# delete the topic (run via `make test`). Uses the CLI tools bundled in the broker image
# via `docker compose exec`, so the only host dependency stays "Docker".
. "$(dirname "$0")/lib.sh"

echo "kafka (stream):"
topic="smoke-${RANDOM}${RANDOM}"
marker="smoke-${RANDOM}"
k() { docker compose exec -T stream-kafka "$@"; }
bs=localhost:9092  # in-container INTERNAL listener

# Create a single-partition, RF=1 topic (the only RF a single node allows).
k /opt/kafka/bin/kafka-topics.sh --bootstrap-server "$bs" \
  --create --topic "$topic" --partitions 1 --replication-factor 1 >/dev/null \
  && pass "create topic (RF=1)" || fail "create topic"

# Produce one record, then consume exactly one back and check it matches.
printf '%s\n' "$marker" | k /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server "$bs" --topic "$topic" >/dev/null 2>&1 \
  && pass "produce" || fail "produce"

# `|| true` keeps a consumer timeout (the broken-round-trip case) from tripping
# `set -e` inside the command substitution — so cleanup and the labeled fail() below
# both still run instead of the script aborting opaquely here.
got="$(k /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server "$bs" \
  --topic "$topic" --from-beginning --max-messages 1 --timeout-ms 20000 2>/dev/null | tr -d '\r' || true)"

# Clean up the topic regardless of the assertion outcome.
k /opt/kafka/bin/kafka-topics.sh --bootstrap-server "$bs" --delete --topic "$topic" >/dev/null 2>&1 || true

[ "$got" = "$marker" ] && pass "consume round-trip" || fail "consume round-trip (got: $got)"
