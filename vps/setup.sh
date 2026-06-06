#!/usr/bin/env bash
# Run ONCE as root on a fresh bare VPS. Idempotent. Turns the box into a dumb SSH+nftables pipe
# (no app software). After this, drive everything from your laptop with `make expose` / `make allow`.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"

echo "[1/2] sshd: GatewayPorts (for reverse forwards) + key-only root"
cat > /etc/ssh/sshd_config.d/99-quickstart.conf <<'EOF'
GatewayPorts clientspecified
PermitRootLogin prohibit-password
EOF
systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || service ssh reload

echo "[2/2] nftables: default-drop firewall with a named allowlist set"
mkdir -p /etc/nftables.d
touch /etc/nftables.d/allowlist.nft
install -m 0644 "$here/nftables.conf" /etc/nftables.conf
systemctl enable nftables 2>/dev/null || true
nft -f /etc/nftables.conf

echo
echo "Done. The box exposes nothing yet — open your IP from your laptop:"
echo "    make allow-me     # then: make expose"
