#!/usr/bin/env bash
# Server-side: stop explorer stack and wipe RPC + Postgres data (fresh Blockscout index).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib.sh
source "${ROOT_DIR}/scripts/remote/lib.sh"

FORCE=false
while [ $# -gt 0 ]; do
  case "$1" in
    --force) FORCE=true ;;
    -h|--help)
      cat <<'EOF'
Usage: ./scripts/remote/clean-explorer.sh [--force]

Stop Blockscout explorer stack (RPC + Blockscout + stats) and remove chain/DB data.
Keeps genesis/, nodes/rpc/keystore structure, and env files.

Options:
  --force   Do not prompt
EOF
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

cd "${ROOT_DIR}"
remote_require_docker

if [ "${FORCE}" != true ]; then
  read -r -p "Wipe explorer RPC + Blockscout DB data on this server? [y/N] " ans
  [ "${ans}" = "y" ] || [ "${ans}" = "Y" ] || exit 0
fi

mapfile -t COMPOSE_ARGS < <(remote_explorer_compose_args "${ROOT_DIR}")

echo "=== Stop explorer stack ==="
docker compose "${COMPOSE_ARGS[@]}" down --remove-orphans 2>/dev/null || true

SERVICES_DATA="${ROOT_DIR}/../services/data"
echo "=== Wipe Postgres bind mounts ==="
rm -rf "${SERVICES_DATA}/dpos-blockscout-db"/* "${SERVICES_DATA}/dpos-stats-db"/* 2>/dev/null || true

echo "=== Wipe RPC chain data ==="
rm -rf "${ROOT_DIR}/nodes/rpc/data"/* 2>/dev/null || true

echo "Explorer data wiped. Redeploy: ./scripts/remote/deploy-explorer.sh"
