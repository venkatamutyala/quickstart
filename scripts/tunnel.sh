#!/usr/bin/env bash
# Expose local GUIs (default: pgAdmin, Garage UI, Valkey UI, RabbitMQ UI) via
# Microsoft Dev Tunnels so you can reach them from a browser when this stack runs
# on a remote/headless box.
#
#   ./scripts/tunnel.sh            # tunnel the bundled GUIs (ports from .env)
#   ./scripts/tunnel.sh 9000       # tunnel a specific port instead
#   ./scripts/tunnel.sh 8080 3909  # tunnel several explicit ports
#   ANON=1 ./scripts/tunnel.sh     # allow anonymous access (anyone with the URL)
#
# Auth is handled by `make tunnel-login` (GitHub, device-code friendly).
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f .env ] || { echo "No .env found. Run 'make init' first." >&2; exit 1; }
set -a; . ./.env; set +a

if ! command -v devtunnel >/dev/null 2>&1; then
  cat >&2 <<EOF
devtunnel CLI not found. Install it, then run 'make tunnel-login':
  Linux  : curl -sL https://aka.ms/DevTunnelCliInstall | bash
  macOS  : brew install --cask devtunnel
  Windows: winget install Microsoft.devtunnel
  Docs   : https://aka.ms/devtunnels/docs
EOF
  exit 1
fi

if devtunnel user show 2>&1 | grep -qi "not logged in"; then
  echo "Not logged in to dev tunnels. Run:  make tunnel-login" >&2
  exit 1
fi

if [ "$#" -gt 0 ]; then
  PORTS=("$@")
  default_guis=0
else
  PORTS=("${PGADMIN_PORT:-8080}" "${GARAGE_UI_PORT:-3909}" \
         "${VALKEY_UI_PORT:-8081}" "${RABBITMQ_MANAGEMENT_PORT:-15672}")
  default_guis=1
fi

PORT_FLAGS=()
for p in "${PORTS[@]}"; do PORT_FLAGS+=(-p "$p"); done

ANON_FLAG=()
if [ "${ANON:-0}" = "1" ]; then
  ANON_FLAG=(--allow-anonymous)
  echo "!! Anonymous access ENABLED — anyone with the URL can reach these ports"
fi

if [ "$default_guis" = "1" ]; then
  # Match each https://*-<port>.devtunnels.ms URL printed below to a GUI. Most
  # open straight in; RabbitMQ is the only one with a login, so show its creds.
  cat <<EOF
Exposing the bundled GUIs via dev tunnel:
  pgAdmin    port ${PGADMIN_PORT:-8080}   — opens straight in (Postgres pre-connected)
  Garage UI  port ${GARAGE_UI_PORT:-3909}   — opens straight in
  Valkey UI  port ${VALKEY_UI_PORT:-8081}   — opens straight in
  RabbitMQ   port ${RABBITMQ_MANAGEMENT_PORT:-15672}  — log in with  ${RABBITMQ_USER:-rabbit} / ${RABBITMQ_PASSWORD:-<set RABBITMQ_PASSWORD in .env>}
EOF
else
  echo "Exposing ports via dev tunnel: ${PORTS[*]}"
fi
echo "Open the per-port https://*.devtunnels.ms URLs printed below. Ctrl-C to stop."
echo
exec devtunnel host "${PORT_FLAGS[@]}" "${ANON_FLAG[@]}"
