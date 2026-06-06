# Troubleshooting

**pgAdmin asks for a password.** `pgadmin/pgpass` must exist and be mode 600 with creds matching
`.env`. Fix: `make init` (regenerates it), then `docker compose --profile tools up -d --force-recreate pgadmin`.

**`make up-lean` app hangs / slow to start.** An OTEL exporter is retrying with no collector. Ensure
`OTEL_SDK_DISABLED=true` for the lean path (default), or use `make up` (starts the collector).

**Traefik: "client version 1.24 is too old".** You're on Traefik < v3.7. The repo pins `traefik:v3.7`;
don't downgrade.

**HTTPS cert doesn't issue / browser warning.** TLS-ALPN-01 needs the tunnel up and port 443 forwarded.
Check: tunnel alive (`docker compose ps autossh`), your IP is allowlisted (`make allowed`), DNS resolves
(`dig app.$EXPOSE_HOST`), and you haven't hit the sslip.io LE rate limit (50/week). `make cert-expiry`
shows the current cert.

**Locked out of an exposed service (but not the box).** Port 22 stays open — SSH in and
`make allow-me` again, or `ssh root@$VPS 'nft list set inet filter allowlist'`.

**Tunnel dropped / cert silently expiring.** `autossh` has `restart: always` + a healthcheck; it should
self-heal. If not: `docker compose restart autossh`, then re-hit the URL to renew. `make debug-expose`
summarizes tunnel + cert + route health.

**`make expose` aborts "VPS :443 already bound".** Another POC is exposed. `make unexpose` there first
(one POC at a time on the shared VPS).

**GHCR pull fails / image private.** New packages default private — flip visibility once in the package
settings (`docs/ci.md`).

**Traefik label changes ignored.** Typos fail silently. `make validate-labels` dumps how Traefik parsed
the routers; also check `exposedByDefault: false` means you need `traefik.enable=true`.
