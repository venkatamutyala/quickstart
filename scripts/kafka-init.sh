#!/usr/bin/env bash
# Create the Kafka topics declared in .env (KAFKA_TOPICS) so they exist after `make up`.
# Idempotent — uses `--if-not-exists`, so re-running leaves existing topics untouched and
# never fails. Replication factor is always 1 (single node). The broker also auto-creates
# topics on first use and apps can declare them via the AdminClient — this just pre-creates
# the specific ones named in KAFKA_TOPICS (empty by default, so this is a no-op then).
#   KAFKA_TOPICS="orders,events:3"   # 'name' (default partitions) or 'name:partitions'
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f .env ] || { echo "No .env found. Run 'make init' first." >&2; exit 1; }
set -a; . ./.env; set +a

TOPICS="${KAFKA_TOPICS:-}"
DEFAULT_PARTITIONS="${KAFKA_DEFAULT_PARTITIONS:-1}"

if [ -z "${TOPICS// /}" ]; then
  echo "Kafka: no topics declared in KAFKA_TOPICS — skipping (app manages its own topics)."
  exit 0
fi

# Run kafka-topics.sh inside the broker, against the in-container INTERNAL listener.
kt() { docker compose exec -T stream-kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 "$@"; }

# Split on commas; each entry is 'name' or 'name:partitions'.
IFS=',' read -ra _entries <<< "$TOPICS"
for entry in "${_entries[@]}"; do
  name="${entry%%:*}"
  parts="${entry##*:}"
  # trim surrounding whitespace from the name
  name="$(printf '%s' "$name" | tr -d '[:space:]')"
  [ -z "$name" ] && continue
  # no ':' in the entry -> use the default partition count
  if [ "$parts" = "$entry" ] || [ -z "${parts//[[:space:]]/}" ]; then
    parts="$DEFAULT_PARTITIONS"
  fi
  parts="$(printf '%s' "$parts" | tr -d '[:space:]')"
  # Validate before handing to the CLI: a bad count (e.g. 'events:abc' or 'events:0') would
  # otherwise abort 'make up' with a raw Java error. Skip the entry with a clear message instead.
  case "$parts" in ''|*[!0-9]*) echo "Kafka: skipping '$name' — partition count '$parts' is not a positive integer." >&2; continue ;; esac
  [ "$parts" -ge 1 ] || { echo "Kafka: skipping '$name' — partitions must be >= 1 (got '$parts')." >&2; continue; }
  echo "Kafka: ensuring topic '$name' (partitions=$parts, replication-factor=1) ..."
  kt --create --if-not-exists --topic "$name" --partitions "$parts" --replication-factor 1 >/dev/null
done

echo "Kafka ready: topics [$TOPICS]."
