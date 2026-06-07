#!/usr/bin/env bash
# Cheatsheet for the quickstart debug box. Every command below is ready to run: the
# clients are pre-wired to the stack via environment variables (see the `debug` service in
# docker-compose.yaml), so no hosts/ports/credentials need to be typed. Run `help` anytime.
set -u

b=$'\033[1m'; c=$'\033[36m'; d=$'\033[2m'; x=$'\033[0m'

cat <<EOF

${b}quickstart debug box${x} — backend CLIs preloaded & wired to the compose network.
${d}Reach the stack by service name (db-postgres, s3-garage, cache-valkey, queue-rabbitmq,
stream-kafka, search-opensearch). Run 'make up' on the host first if nothing responds.${x}

${b}Postgres${x}  ${d}(psql/pg_dump are pre-wired via PG* env)${x}
  ${c}psql${x}                                          # connect to \$PGDATABASE as \$PGUSER
  ${c}psql -c '\\l'${x}                                  # list databases
  ${c}pg_dump \$PGDATABASE > /work/dump.sql${x}

${b}S3 (Garage)${x}  ${d}(aws -> \$AWS_ENDPOINT_URL, mc -> alias 'garage')${x}
  ${c}aws s3 ls${x}                                     # list buckets
  ${c}aws s3 cp /etc/hostname s3://\$GARAGE_BUCKET/${x}
  ${c}mc ls garage/${x}                                 # same, via MinIO client
  ${c}mc cp /etc/hostname garage/\$GARAGE_BUCKET/${x}

${b}Valkey (cache)${x}  ${d}(auth via \$REDISCLI_AUTH)${x}
  ${c}redis-cli -h cache-valkey ping${x}                # -> PONG
  ${c}redis-cli -h cache-valkey set k v${x}

${b}Kafka (stream)${x}  ${d}(\$KAFKA_BOOTSTRAP = stream-kafka:9092)${x}
  ${c}kcat -b \$KAFKA_BOOTSTRAP -L${x}                    # cluster + topic metadata
  ${c}kafka-topics.sh --bootstrap-server \$KAFKA_BOOTSTRAP --list${x}
  ${c}kafka-console-producer.sh --bootstrap-server \$KAFKA_BOOTSTRAP --topic demo${x}
  ${c}kafka-console-consumer.sh --bootstrap-server \$KAFKA_BOOTSTRAP --topic demo --from-beginning${x}

${b}RabbitMQ (queue)${x}  ${d}(\$AMQP_URL set; mgmt API on :15672)${x}
  ${c}curl -s -u \$RABBITMQ_USER:\$RABBITMQ_PASSWORD queue-rabbitmq:15672/api/overview | jq .${x}
  ${c}amqp-declare-queue -u "\$AMQP_URL" -q demo${x}
  ${c}amqp-publish    -u "\$AMQP_URL" -r demo -b "hello"${x}
  ${c}amqp-get        -u "\$AMQP_URL" -q demo${x}

${b}OpenSearch (search)${x}  ${d}(\$OPENSEARCH_URL set; no auth)${x}
  ${c}curl -s \$OPENSEARCH_URL/_cluster/health?pretty${x}
  ${c}curl -s \$OPENSEARCH_URL/_cat/indices?v${x}

${b}Network debug${x}
  ${c}dig db-postgres${x}        ${c}getent hosts stream-kafka${x}
  ${c}nc -zv stream-kafka 9092${x}

${d}Tip: full connection details for host + in-Docker contexts are on the host via 'make conn'.${x}
EOF
