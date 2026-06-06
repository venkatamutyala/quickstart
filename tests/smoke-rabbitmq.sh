#!/usr/bin/env bash
# Smoke test: RabbitMQ — declare/publish/get/delete round-trip via the management
# HTTP API (run via `make test`). Uses a throwaway curl container on the compose
# network, so the only host dependency stays "Docker" (curl is MIT/curl-licensed).
. "$(dirname "$0")/lib.sh"

echo "rabbitmq (queue):"
net="$(compose_network)"
marker="smoke-${RANDOM}${RANDOM}"
queue="smoke-${RANDOM}"

if out=$(docker run --rm --network "$net" \
      -e U="$RABBITMQ_USER" -e P="$RABBITMQ_PASSWORD" -e Q="$queue" -e MARKER="$marker" \
      --entrypoint sh curlimages/curl:latest -ec '
        api="http://queue-rabbitmq:15672/api"
        cu() { curl -fsS -u "$U:$P" -H "content-type: application/json" "$@"; }
        # declare a queue on the default vhost (/), publish to it via the default
        # exchange (routing key = queue name), then fetch the message back.
        cu -X PUT  "$api/queues/%2F/$Q" -d "{\"durable\":false}" >/dev/null
        cu -X POST "$api/exchanges/%2F/amq.default/publish" \
           -d "{\"properties\":{},\"routing_key\":\"$Q\",\"payload\":\"$MARKER\",\"payload_encoding\":\"string\"}" >/dev/null
        got=$(cu -X POST "$api/queues/%2F/$Q/get" \
           -d "{\"count\":1,\"ackmode\":\"ack_requeue_false\",\"encoding\":\"auto\"}")
        cu -X DELETE "$api/queues/%2F/$Q" >/dev/null
        echo "$got" | grep -q "$MARKER"
      ' 2>&1); then
  pass "declare/publish/get/delete round-trip (management API)"
else
  echo "$out" >&2
  fail "RabbitMQ round-trip"
fi
