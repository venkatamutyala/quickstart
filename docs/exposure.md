# Exposure — SSH reverse tunnel + local Traefik

Expose your locally-running stack to the internet through a **bare VPS** (only `sshd` + kernel
`nftables` — no app software). Everything else (Traefik ingress, TLS, your services) stays local in
Docker. The VPS is shared infra across all your POCs.

```
Internet ──443/5432/6379──> VPS (sshd GatewayPorts + nftables allowlist)
                                  ▲  ssh -R  (autossh container, local)
Local Docker:  Traefik (TLS + label routing) ──> app/pgadmin ; db ; valkey
```

## One-time VPS setup (run once, as root, on a fresh box)
```bash
scp -r vps/ root@<vps-ip>:/root/quickstart-vps && ssh root@<vps-ip> 'bash /root/quickstart-vps/setup.sh'
```
This sets `GatewayPorts clientspecified` + key-only root in sshd, and loads `nftables.conf`
(default-drop; port 22 open to all so you can't lock yourself out; 443/5432/6379 only from the
`@allowlist` set).

## Per-POC
1. In `.env`: `TUNNEL_VPS_HOST=<vps-ip>`, `EXPOSE_HOST=<vps-ip-with-dashes>.sslip.io`
   (e.g. `203.0.113.10` → `203-0-113-10.sslip.io`). Your SSH key must be in your `ssh-agent`.
2. `make allow-me` — allowlist your current public IP.
3. `make expose` — starts local Traefik + autossh (and aborts if the VPS :443 is already in use by
   another POC). `make urls` prints the addresses.
4. Reach `https://app.$EXPOSE_HOST` (real Let's Encrypt cert via TLS-ALPN-01, terminated locally),
   and `psql -h <vps-ip> -p 5432` / `redis-cli -h <vps-ip> -p 6379`.

## Access control (IP allowlist)
The allowlist lives on the VPS (kernel nftables) — the **only** place that sees the real client IP,
because `ssh -R` makes a local proxy see `127.0.0.1`. Manage it over SSH, no cron/daemon:
```bash
make allow IP=1.2.3.4      # live + persisted (survives reboot)
make allow-range CIDR=…/24
make deny IP=1.2.3.4
make allowed               # list
```

## Key facts / gotchas
- **HTTPS without a domain:** `sslip.io` resolves `*.<ip>.sslip.io` to your VPS IP; Let's Encrypt
  issues real certs via **TLS-ALPN-01** (only 443 forwarded). sslip.io shares an LE rate limit
  (50 certs/week) — fine for a few hostnames; buy a cheap domain if you iterate heavily.
- **Traefik must be v3.7+** — older versions default their Docker client to API v1.24, which modern
  Docker (MinAPIVersion 1.40) rejects.
- **Single POC at a time** exposes on the shared VPS (port 443). `make unexpose` before switching.
- TLS terminates locally; the VPS only ever sees ciphertext. Raw TCP (DB/Valkey) is gated by the
  allowlist + the DB password (no app-layer auth on raw TCP).
- See `docs/troubleshooting.md` for tunnel/cert recovery and `docs/production-hardening.md` for the
  dev→prod upgrade path.
