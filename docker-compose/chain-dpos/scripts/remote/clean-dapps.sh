#!/usr/bin/env bash
# Server-side: stop DApps stack and wipe RPC chain data (fresh archive sync).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib.sh
source "${ROOT_DIR}/scripts/remote/lib.sh"

FORCE=false
PRUNE_IMAGES=false
while [ $# -gt 0 ]; do
  case "$1" in
    --force) FORCE=true ;;
    --prune-images) PRUNE_IMAGES=true ;;
    -h|--help)
      cat <<'EOF'
Usage: ./scripts/remote/clean-dapps.sh [--force] [--prune-images]

Stop DApps stack (Traefik, RPC archive, netstats-dashboard, docs-static) and
remove RPC chain data. Keeps genesis/, nodes/rpc config, and env files.

Options:
  --force         Do not prompt
  --prune-images  Remove project Docker images after down (fresh pull on redeploy)
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
  read -r -p "Wipe DApps RPC chain data on this server? [y/N] " ans
  [ "${ans}" = "y" ] || [ "${ans}" = "Y" ] || exit 0
fi

COMPOSE_ARGS=(-f compose-dapps-traefik-v11.yml)

echo "=== Stop DApps stack ==="
docker compose "${COMPOSE_ARGS[@]}" down --remove-orphans 2>/dev/null || true

echo "=== Wipe RPC chain data ==="
rm -rf "${ROOT_DIR}/nodes/rpc/data"/* 2>/dev/null || true
mkdir -p "${ROOT_DIR}/nodes/rpc/data"

if [ "${PRUNE_IMAGES}" = true ]; then
  echo "=== Remove project Docker images ==="
  docker images --format '{{.Repository}}:{{.Tag}}' \
    | grep -E 'congquang295/blockchain-dock|traefik:|nginx:alpine' \
    | while read -r img; do
        docker rmi -f "${img}" 2>/dev/null || true
      done
  docker image prune -f
fi

echo "DApps data wiped. Redeploy: ./scripts/remote/deploy-dapps.sh"
