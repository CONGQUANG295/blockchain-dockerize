#!/usr/bin/env bash
# Server-side: deploy DApps stack (RPC, Blockscout v11, Traefik, faucet on testnet).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib.sh
source "${ROOT_DIR}/scripts/remote/lib.sh"

WITH_TRAEFIK=true
SKIP_HEALTH=false

usage() {
  cat <<'EOF'
Usage: ./scripts/remote/deploy-dapps.sh [options]

Deploy DApps + RPC archive node. Validator chain must already be running.

Options:
  --no-traefik       Do not require Traefik domains in deploy.env
  --skip-health      Skip health-check.sh
  -h, --help         Show this help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --no-traefik) WITH_TRAEFIK=false ;;
    --skip-health) SKIP_HEALTH=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

cd "${ROOT_DIR}"

remote_require_docker
remote_require_deploy_env "${ROOT_DIR}"
remote_require_cmd curl
remote_require_cmd jq

if [ ! -f genesis/reserved-peers.txt ] && [ ! -f genesis/validator-1.enode ]; then
  echo "Missing peer bundle (genesis/reserved-peers.txt) — run deploy-validator.sh or export-peer-config.sh first." >&2
  exit 1
fi

RENDER_ARGS=()
[ "${WITH_TRAEFIK}" = true ] && RENDER_ARGS+=(--with-traefik)

echo "=== Render env + images (Docker Hub: ${DOCKERHUB_NAMESPACE}) ==="
./scripts/render-envs.sh envs/deploy.env "${RENDER_ARGS[@]}"

echo "=== Prepare RPC node + DApps env ==="
./scripts/prepare-rpc-node.sh
WITH_TRAEFIK_PREPARE=$([ "${WITH_TRAEFIK}" = true ] && echo true || echo false) \
  ./scripts/prepare-envs-dapps.sh

set -a
# shellcheck disable=SC1090
source envs/dpos.chain.env
set +a

COMPOSE_ARGS=(-f compose-dapps-traefik-v11.yml)
if [ "${NETWORK_TYPE}" = testnet ]; then
  COMPOSE_ARGS+=(--profile faucet)
else
  echo "Mainnet: skipping faucet profile"
fi

echo "=== Pull + start DApps ==="
docker compose "${COMPOSE_ARGS[@]}" pull
docker compose "${COMPOSE_ARGS[@]}" up -d

if [ "${SKIP_HEALTH}" = false ]; then
  ./scripts/health-check.sh
fi

echo "DApps deploy complete."
