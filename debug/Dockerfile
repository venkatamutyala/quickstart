# On-demand debug box for the quickstart stack: every backend's native CLI, preloaded
# and joined to the compose network. Built locally (the stack's only built image) — so we
# pin the base by digest and verify every downloaded binary by checksum, keeping the spirit
# of the repo's "pin by digest" rule. No connection details or secrets live here: they come
# from .env + in-Docker hostnames at runtime (see the `debug` service in docker-compose.yaml).
FROM ubuntu:24.04@sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517

ENV DEBIAN_FRONTEND=noninteractive

# Native CLIs (Postgres, Valkey/Redis, S3/aws, RabbitMQ, Kafka quick client) + HTTP/JSON
# tooling for OpenSearch + the usual network-debug kit. --no-install-recommends keeps it lean.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl wget jq unzip \
      postgresql-client \
      redis-tools \
      amqp-tools \
      kcat \
      default-jre-headless \
      dnsutils iputils-ping netcat-openbsd \
      less vim-tiny bash-completion \
 && rm -rf /var/lib/apt/lists/*

# AWS CLI v2 — the official installer (Ubuntu 24.04 dropped the apt `awscli` package, and
# v2 isn't on apt/pip anyway). Pin the version + per-arch SHA-256 (computed from the
# versioned download URL). Bump AWS_CLI_VERSION + both checksums together to update.
ARG TARGETARCH
ARG AWS_CLI_VERSION=2.34.63
ARG AWS_CLI_SHA256_amd64=bc15b053ef5710be63c9d8c54089ec6847737457a936a10b120a0a4d08c7c771
ARG AWS_CLI_SHA256_arm64=23ed2f830b3be601ad0d8f9c29c7f4a3695a555486de7ed24dff45df9e0860d1
RUN set -eux; \
    arch="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    case "$arch" in \
      amd64) awsarch=x86_64;  sha="$AWS_CLI_SHA256_amd64" ;; \
      arm64) awsarch=aarch64; sha="$AWS_CLI_SHA256_arm64" ;; \
      *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    wget -O /tmp/awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-${awsarch}-${AWS_CLI_VERSION}.zip"; \
    echo "${sha}  /tmp/awscliv2.zip" | sha256sum -c -; \
    unzip -q /tmp/awscliv2.zip -d /tmp; \
    /tmp/aws/install; \
    rm -rf /tmp/awscliv2.zip /tmp/aws

# Apache Kafka's official CLI suite (kafka-topics.sh, kafka-console-{producer,consumer}.sh, …).
# Pull from archive.apache.org (immutable, unlike downloads.apache.org) and verify the
# upstream SHA-512. Keep KAFKA_VERSION in step with the broker image in docker-compose.yaml.
ARG KAFKA_VERSION=4.2.1
ARG KAFKA_SCALA=2.13
ARG KAFKA_SHA512=f643e31266268e920aa98ead9a061026c98dac2886932ad468565ba59bcb7fb4f98a4c4f62727367e1bd87515f3b016e6f6ccccad8b12bdef8b091b0fb577170
RUN set -eux; \
    wget -O /tmp/kafka.tgz "https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_${KAFKA_SCALA}-${KAFKA_VERSION}.tgz"; \
    echo "${KAFKA_SHA512}  /tmp/kafka.tgz" | sha512sum -c -; \
    mkdir -p /opt/kafka; \
    tar -xzf /tmp/kafka.tgz -C /opt/kafka --strip-components=1; \
    rm /tmp/kafka.tgz
ENV PATH="/opt/kafka/bin:${PATH}"

# MinIO mc — the ergonomic S3 client for Garage. MinIO ships dated RELEASE.* builds (not
# semver), so pin a specific release + per-arch SHA-256. NOTE: Renovate won't bump this —
# update MC_RELEASE and both checksums by hand from
# https://dl.min.io/client/mc/release/linux-<arch>/mc.sha256sum
ARG TARGETARCH
ARG MC_RELEASE=RELEASE.2025-08-13T08-35-41Z
ARG MC_SHA256_amd64=01f866e9c5f9b87c2b09116fa5d7c06695b106242d829a8bb32990c00312e891
ARG MC_SHA256_arm64=14c8c9616cfce4636add161304353244e8de383b2e2752c0e9dad01d4c27c12c
RUN set -eux; \
    arch="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    case "$arch" in \
      amd64) sha="$MC_SHA256_amd64" ;; \
      arm64) sha="$MC_SHA256_arm64" ;; \
      *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    wget -O /usr/local/bin/mc "https://dl.min.io/client/mc/release/linux-${arch}/archive/mc.${MC_RELEASE}"; \
    echo "${sha}  /usr/local/bin/mc" | sha256sum -c -; \
    chmod +x /usr/local/bin/mc

# Garage is path-style only (no virtual-host buckets) — make the aws CLI use it by default.
RUN mkdir -p /root/.aws \
 && printf '[default]\ns3 =\n    addressing_style = path\n' > /root/.aws/config

# `help` cheatsheet + a one-line welcome on interactive login. The script is installed as
# `quickstart-help`; the profile script defines a `help` shell function that shadows bash's
# `help` builtin (functions win over builtins) so plain `help` shows the cheatsheet.
COPY quickstart-help.sh /usr/local/bin/quickstart-help
COPY motd.sh /etc/profile.d/00-quickstart.sh
RUN chmod +x /usr/local/bin/quickstart-help

WORKDIR /work
CMD ["bash", "-l"]
