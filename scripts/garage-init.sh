#!/usr/bin/env bash
# Initialize a single-node Garage cluster so it's usable for S3:
#   1. assign + apply a cluster layout (one node)
#   2. import the S3 access key from .env (deterministic creds)
#   3. create the bucket and grant the key access
# Idempotent — safe to run on every `make up`.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f .env ] || { echo "No .env found. Run 'make init' first." >&2; exit 1; }
set -a; . ./.env; set +a

# Enforce that the S3 secrets are actually set (not just present-but-empty).
: "${GARAGE_ACCESS_KEY_ID:?missing in .env — run 'make init'}"
: "${GARAGE_SECRET_ACCESS_KEY:?missing in .env — run 'make init'}"
: "${GARAGE_BUCKET:?missing in .env — run 'make init'}"
: "${GARAGE_KEY_NAME:?missing in .env — run 'make init'}"

g() { docker compose exec -T -e RUST_LOG=error s3-garage /garage "$@"; }

# 1. Cluster layout (only if this node has no role yet)
if g status 2>/dev/null | grep -q "NO ROLE ASSIGNED"; then
  NODE="$(g node id -q 2>/dev/null | tr -d '\r' | cut -d@ -f1)"
  echo "Garage: assigning layout to node ${NODE:0:16}..."
  g layout assign "$NODE" -z dc1 -c 1G >/dev/null
  CUR="$(g layout show 2>/dev/null | grep -i 'Current cluster layout version' | grep -oE '[0-9]+' | head -1)"
  g layout apply --version "$(( ${CUR:-0} + 1 ))" >/dev/null
fi

# 2. S3 access key (import the one from .env if not already present)
if ! g key list 2>/dev/null | grep -q "$GARAGE_ACCESS_KEY_ID"; then
  echo "Garage: importing S3 key $GARAGE_ACCESS_KEY_ID ..."
  g key import "$GARAGE_ACCESS_KEY_ID" "$GARAGE_SECRET_ACCESS_KEY" -n "$GARAGE_KEY_NAME" --yes >/dev/null
fi

# 3. Bucket + permissions ('bucket info' is an exact lookup — avoids substring false-matches)
if ! g bucket info "$GARAGE_BUCKET" >/dev/null 2>&1; then
  echo "Garage: creating bucket $GARAGE_BUCKET ..."
  g bucket create "$GARAGE_BUCKET" >/dev/null
fi
g bucket allow --read --write --owner "$GARAGE_BUCKET" --key "$GARAGE_KEY_NAME" >/dev/null

echo "Garage ready: bucket '$GARAGE_BUCKET', key '$GARAGE_ACCESS_KEY_ID'."
