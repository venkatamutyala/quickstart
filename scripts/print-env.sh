#!/usr/bin/env bash
# Print eval-able shell exports for connecting an app on the HOST to the stack.
#   eval "$(make env)"      # then run your app — DATABASE_URL / PG* / AWS_* are set
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] || { echo "No .env found. Run 'make init' first." >&2; exit 1; }
set -a; . ./.env; set +a

cat <<EOF
export DATABASE_URL='postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@localhost:$PGPORT/$POSTGRES_DB?sslmode=disable'
export PGHOST='localhost' PGPORT='$PGPORT' PGDATABASE='$POSTGRES_DB' PGUSER='$POSTGRES_USER' PGPASSWORD='$POSTGRES_PASSWORD' PGSSLMODE='disable'
export AWS_ACCESS_KEY_ID='$GARAGE_ACCESS_KEY_ID' AWS_SECRET_ACCESS_KEY='$GARAGE_SECRET_ACCESS_KEY'
export AWS_REGION='$GARAGE_REGION' AWS_ENDPOINT_URL='http://localhost:$GARAGE_S3_PORT'
export S3_BUCKET='$GARAGE_BUCKET'
EOF
