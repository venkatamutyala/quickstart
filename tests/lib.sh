# Shared helpers for smoke tests. Source from each tests/smoke-*.sh:
#   . "$(dirname "$0")/lib.sh"
# Tests assume the stack is already running (run `make up` first).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[ -f .env ] || { echo "No .env found — run 'make init && make up' first." >&2; exit 1; }
set -a; . ./.env; set +a

_g=$'\033[32m'; _r=$'\033[31m'; _x=$'\033[0m'
pass() { printf '  %sok%s   %s\n' "$_g" "$_x" "$1"; }
fail() { printf '  %sFAIL%s %s\n' "$_r" "$_x" "$1" >&2; exit 1; }

# Name of the Compose network (derived from the directory, like scripts/conn.sh).
compose_network() {
  printf '%s_default\n' "$(basename "$ROOT" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')"
}
