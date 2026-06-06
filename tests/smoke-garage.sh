#!/usr/bin/env bash
# Smoke test: Garage S3 — path-style put/list/get/delete round-trip (run via `make test`).
# Uses a throwaway aws-cli container on the compose network, so the only host
# dependency stays "Docker" (the aws-cli itself is Apache-2.0).
. "$(dirname "$0")/lib.sh"

echo "garage (s3):"
net="$(compose_network)"
marker="smoke-${RANDOM}${RANDOM}"
key="smoke/${marker}.txt"

if out=$(docker run --rm --network "$net" \
      -e AWS_ACCESS_KEY_ID="$GARAGE_ACCESS_KEY_ID" \
      -e AWS_SECRET_ACCESS_KEY="$GARAGE_SECRET_ACCESS_KEY" \
      -e AWS_REGION="$GARAGE_REGION" -e AWS_EC2_METADATA_DISABLED=true \
      -e EP="http://s3-garage:3900" -e BUCKET="$GARAGE_BUCKET" -e KEY="$key" -e MARKER="$marker" \
      --entrypoint sh amazon/aws-cli:latest -ec '
        printf "%s" "$MARKER" > /tmp/obj
        aws --endpoint-url "$EP" s3 cp /tmp/obj "s3://$BUCKET/$KEY" >/dev/null
        aws --endpoint-url "$EP" s3 ls "s3://$BUCKET/$KEY" >/dev/null
        got=$(aws --endpoint-url "$EP" s3 cp "s3://$BUCKET/$KEY" -)
        test "$got" = "$MARKER"
        aws --endpoint-url "$EP" s3 rm "s3://$BUCKET/$KEY" >/dev/null
      ' 2>&1); then
  pass "put/list/get/delete round-trip (path-style)"
else
  echo "$out" >&2
  fail "S3 round-trip"
fi
