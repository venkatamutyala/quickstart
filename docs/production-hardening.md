# Production hardening (dev → prod)

The `expose` layer is intentionally **dev/POC-only, single-trusted-operator**. Before anything
real, upgrade:

- **SSH user:** replace root SSH with a dedicated, no-shell tunnel user
  (`authorized_keys`: `restrict,port-forwarding,no-pty …`, an sshd `Match User` block with
  `AllowTcpForwarding remote` + `PermitOpen` limited to 443/5432/6379). Root binds privileged ports
  for free, which is why the POC default uses it — a non-root user needs a kernel tweak
  (`sysctl net.ipv4.ip_unprivileged_port_start=80`) or an nftables redirect.
- **Docker socket:** Traefik already talks to a read-only `docker-socket-proxy` (not the raw socket).
  Keep `POST=0` and only the endpoints it needs.
- **TLS / hostnames:** move off `sslip.io` to a domain you own (avoids the shared LE rate limit and
  the certificate-transparency logs that expose your VPS IP + hostnames). DNS-01 then enables wildcards.
- **Database auth:** per-service DB users/roles with least privilege; TLS to Postgres; don't expose
  raw DB ports publicly if you can avoid it (reach them via the app or a bastion).
- **Registry:** swap the broad `GITHUB_TOKEN` for a fine-grained, repo-scoped PAT or OIDC.
- **Availability:** the local-machine + single-tunnel model has no redundancy. For always-on, run the
  app on real infra (k8s/ECS/Fly) and use the tunnel only for dev.
- **Resource limits:** add `deploy.resources` / `mem_limit` so co-located POCs can't starve each other.
- **Observability:** `grafana/otel-lgtm` is explicitly not for production — point OTLP at Grafana
  Cloud or your vendor.
