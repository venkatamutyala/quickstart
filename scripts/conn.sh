#!/usr/bin/env bash
# Print connection details for each service, broken out into individual fields,
# fully-assembled URLs/DSNs for BOTH contexts (from your host, and from inside
# Docker), plus the common options various libraries need. Generic on purpose —
# map them to your language and framework yourself.
#   ./scripts/conn.sh            # all services
#   ./scripts/conn.sh postgres   # just one (postgres|s3|valkey|rabbitmq)
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f .env ] || { echo "No .env found. Run 'make init' first." >&2; exit 1; }
set -a; . ./.env; set +a

FILTER="${1:-}"
want() { [ -z "$FILTER" ] || [ "$FILTER" = "$1" ]; }

# Compose network name (where the in-Docker hostnames resolve).
NET="$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')_default"

cat <<EOF
Two contexts for every service:
  - From your host  : app runs on your machine        -> host 'localhost', the published port
  - From inside Docker: app runs as a container on the '$NET' network -> service name, internal port
To use the in-Docker form, put your app container on that network:
  docker run --network $NET ...     (or add your app as a service in docker-compose.yaml)
EOF

if want postgres; then
cat <<EOF

================================ Postgres ================================
  Database         : $POSTGRES_DB
  User             : $POSTGRES_USER
  Password         : $POSTGRES_PASSWORD
  SSL mode         : disable              (local server has no TLS)

  -- From your host (localhost) --
  Host:Port        : localhost:$PGPORT
  URL              : postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@localhost:$PGPORT/$POSTGRES_DB?sslmode=disable
  DSN (key=value)  : host=localhost port=$PGPORT dbname=$POSTGRES_DB user=$POSTGRES_USER password=$POSTGRES_PASSWORD sslmode=disable
  JDBC             : jdbc:postgresql://localhost:$PGPORT/$POSTGRES_DB?sslmode=disable   (user/password passed separately)
  PG* env          : PGHOST=localhost PGPORT=$PGPORT PGDATABASE=$POSTGRES_DB PGUSER=$POSTGRES_USER PGPASSWORD=$POSTGRES_PASSWORD PGSSLMODE=disable

  -- From inside Docker (service 'db-postgres', internal port 5432) --
  Host:Port        : db-postgres:5432
  URL              : postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@db-postgres:5432/$POSTGRES_DB?sslmode=disable
  DSN (key=value)  : host=db-postgres port=5432 dbname=$POSTGRES_DB user=$POSTGRES_USER password=$POSTGRES_PASSWORD sslmode=disable
  JDBC             : jdbc:postgresql://db-postgres:5432/$POSTGRES_DB?sslmode=disable
  PG* env          : PGHOST=db-postgres PGPORT=5432 PGDATABASE=$POSTGRES_DB PGUSER=$POSTGRES_USER PGPASSWORD=$POSTGRES_PASSWORD PGSSLMODE=disable

  -- Common options (append to the URL as ?k=v&k=v, or set in the DSN) --
  sslmode          : disable | prefer | require | verify-ca | verify-full   (here: disable)
  connect_timeout  : seconds, e.g. connect_timeout=10
  application_name : shows up in pg_stat_activity, e.g. application_name=myapp
  search_path      : URL: options=-c%20search_path%3Dmyschema   (DSN: options='-c search_path=myschema')
  channel_binding  : disable | prefer | require   (SCRAM; ignored when sslmode=disable)
  pool/timeouts    : driver-specific (SQLAlchemy pool_size, pgx pool_max_conns, node-pg max) — set in code.

  -- Driver/SSL notes (behavior against this no-TLS server) --
    psycopg 3 (Py) : plain psycopg.connect(url) honors ?sslmode=disable.
    lib/pq (Go)    : defaults to sslmode=require — you MUST set sslmode=disable or it errors.
    pgx (Go)       : defaults to prefer (connects); keep sslmode=disable in the DSN to be explicit.
                     pgx v5 / current aws-sdk-go-v2 need Go >= 1.25 (pin older tags for older Go).
    asyncpg (Py)   : current versions honor ?sslmode=disable in the URL (ssl=False also works).
    node-postgres  : parses ?sslmode=disable from the URL — no ssl:false needed. (modes other
                     than 'disable' follow node-pg's own semantics, changing in pg v9.)
    SQLAlchemy     : put the driver in the scheme — postgresql+psycopg://  or  postgresql+asyncpg://
EOF
fi

if want s3; then
cat <<EOF

=============================== S3 (Garage) ==============================
  Region           : $GARAGE_REGION                     (the value is arbitrary but most SDKs require one; bucket/object ops need it to match the server's region)
  Access Key ID    : $GARAGE_ACCESS_KEY_ID
  Secret Access Key: $GARAGE_SECRET_ACCESS_KEY
  Bucket           : $GARAGE_BUCKET
  Use TLS          : no (plain http)
  Signature        : AWS Signature v4 (SDK default)

  -- From your host (localhost) --
  S3 Endpoint      : http://localhost:$GARAGE_S3_PORT
  AWS env          : AWS_ENDPOINT_URL=http://localhost:$GARAGE_S3_PORT AWS_REGION=$GARAGE_REGION AWS_ACCESS_KEY_ID=$GARAGE_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$GARAGE_SECRET_ACCESS_KEY
  aws cli          : AWS_ACCESS_KEY_ID=$GARAGE_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$GARAGE_SECRET_ACCESS_KEY aws --endpoint-url http://localhost:$GARAGE_S3_PORT --region $GARAGE_REGION s3 ls
  Admin API        : http://localhost:$GARAGE_ADMIN_PORT      Web UI: http://localhost:$GARAGE_UI_PORT

  -- From inside Docker (service 's3-garage', internal ports) --
  S3 Endpoint      : http://s3-garage:3900
  AWS env          : AWS_ENDPOINT_URL=http://s3-garage:3900 AWS_REGION=$GARAGE_REGION AWS_ACCESS_KEY_ID=$GARAGE_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$GARAGE_SECRET_ACCESS_KEY
  Admin API        : http://s3-garage:3903

  s3 URI (either)  : s3://$GARAGE_BUCKET

  -- Path-style addressing: use it (Garage doesn't do bucket.host virtual-host style) --
  A CLIENT option, not part of the URL. The AWS CLI and boto3 usually auto-enable it for a
  custom endpoint, but the Go/JS SDKs need the flag explicitly — so set it to be safe:
    AWS CLI        : aws configure set default.s3.addressing_style path
    boto3 (Python) : Config(s3={"addressing_style": "path"})        # botocore.config.Config
    aws-sdk-js v3  : new S3Client({ endpoint, region, forcePathStyle: true, credentials })
    aws-sdk-js v2  : new AWS.S3({ endpoint, s3ForcePathStyle: true })
    AWS SDK Go v2  : s3.NewFromConfig(cfg, func(o *s3.Options){ o.BaseEndpoint = aws.String(endpoint); o.UsePathStyle = true })
    AWS SDK Java v2: S3Configuration.builder().pathStyleAccessEnabled(true)
    MinIO SDKs     : path-style by default (no flag needed)
    Terraform aws  : s3_use_path_style = true
    rclone (s3)    : provider=Other, force_path_style=true

  -- Other common options --
  use_ssl/secure   : false  (http endpoint; e.g. boto use_ssl=False, minio secure=False)
  admin auth       : Authorization: Bearer \$GARAGE_ADMIN_TOKEN
EOF
fi

if want valkey; then
cat <<EOF

=============================== Valkey (cache) ===========================
  Password         : $VALKEY_PASSWORD
  User             : default              (Valkey's built-in user; auth is the password only)
  DB index         : 0                    (default; redis:// path segment selects it)
  Use TLS          : no (plain connection)

  -- From your host (localhost) --
  Host:Port        : localhost:$VALKEY_PORT
  URL              : redis://default:$VALKEY_PASSWORD@localhost:$VALKEY_PORT/0
  valkey-cli       : valkey-cli -u redis://default:$VALKEY_PASSWORD@localhost:$VALKEY_PORT
  Web UI           : http://localhost:$VALKEY_UI_PORT   (redis-commander)

  -- From inside Docker (service 'cache-valkey', internal port 6379) --
  Host:Port        : cache-valkey:6379
  URL              : redis://default:$VALKEY_PASSWORD@cache-valkey:6379/0

  Note             : Valkey speaks the Redis protocol — any redis:// client works
                     (redis-py, ioredis, go-redis, lettuce/jedis, …). Use scheme 'rediss://'
                     only for TLS; this server is plaintext, so 'redis://'.
EOF
fi

if want rabbitmq; then
cat <<EOF

============================= RabbitMQ (queue) ===========================
  User             : $RABBITMQ_USER
  Password         : $RABBITMQ_PASSWORD
  Virtual host     : /                     (default; URL-encode as %2F in the AMQP URL path)
  Use TLS          : no (plain amqp)
  Protocol         : AMQP 0-9-1

  -- From your host (localhost) --
  Host:Port        : localhost:$RABBITMQ_PORT
  AMQP URL         : amqp://$RABBITMQ_USER:$RABBITMQ_PASSWORD@localhost:$RABBITMQ_PORT/%2F
  Management UI    : http://localhost:$RABBITMQ_MANAGEMENT_PORT   ($RABBITMQ_USER / $RABBITMQ_PASSWORD)

  -- From inside Docker (service 'queue-rabbitmq', internal port 5672) --
  Host:Port        : queue-rabbitmq:5672
  AMQP URL         : amqp://$RABBITMQ_USER:$RABBITMQ_PASSWORD@queue-rabbitmq:5672/%2F

  Note             : The trailing /%2F is the default vhost '/'; drop it (…:5672/) and most
                     clients also default to '/'. AMQP 0-9-1 clients: pika (Py), amqplib (JS),
                     amqp091-go (Go), Spring AMQP / Bunny. The management HTTP API is on the
                     UI port under /api (same credentials).
EOF
fi
