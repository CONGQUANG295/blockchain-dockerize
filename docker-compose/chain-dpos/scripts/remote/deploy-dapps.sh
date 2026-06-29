#!/usr/bin/env bash
# Server-side: deploy DApps + public RPC archive node (no Blockscout).
# Blockscout explorer → deploy-explorer.sh on EXPLORER_SERVER.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib.sh
source "${ROOT_DIR}/scripts/remote/lib.sh"

WITH_TRAEFIK=true
SKIP_HEALTH=false

# DApps server: Traefik, netstats, docs, RPC archive — no Blockscout / Postgres.
DAPPS_SERVICES=(
  traefik
  openethereum
  netstats-dashboard
  docs-static
)

usage() {
  cat <<'EOF'
Usage: ./scripts/remote/deploy-dapps.sh [options]

Deploy DApps + RPC archive node (netstats-dashboard, docs-static, Traefik, openethereum;
faucet on testnet). Does not start Blockscout — use deploy-explorer.sh on EXPLORER_SERVER.

Options:
  --no-traefik       Do not require Traefik domains in deploy.env
  --skip-health      Skip health-check
  -h, --help         Show this help
EOF
}

remote_health_check_dapps() {
  echo "Health-check: RPC sync + netstats-dashboard..."
  ./scripts/health-check.sh

  echo "Health-check: netstats-dashboard UI (timeout 60s)..."
  local elapsed=0
  while [ "${elapsed}" -lt 60 ]; do
    if docker exec netstats-dashboard sh -c \
      'curl -sf http://127.0.0.1:3006 >/dev/null 2>&1 || wget -qO- http://127.0.0.1:3006 >/dev/null 2>&1' 2>/dev/null; then
      echo "netstats-dashboard ready"
      return 0
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done
  echo "netstats-dashboard not ready" >&2
  return 1
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

# DApps-only: no Blockscout routes (explorer runs on EXPLORER_SERVER)
if [ "${WITH_TRAEFIK}" = true ]; then
  rm -f traefik/dynamic/blockscout-v11.yml
fi

set -a
# shellcheck disable=SC1090
source envs/dpos.chain.env
set +a

COMPOSE_ARGS=(-f compose-dapps-traefik-v11.yml)
if [ "${NETWORK_TYPE}" = testnet ]; then
  COMPOSE_ARGS+=(--profile faucet)
  DAPPS_SERVICES+=(eth-faucet)
else
  echo "Mainnet: skipping faucet profile"
fi

echo "=== Pull + start DApps + RPC (no Blockscout) ==="
docker compose "${COMPOSE_ARGS[@]}" pull "${DAPPS_SERVICES[@]}"
docker compose "${COMPOSE_ARGS[@]}" up -d "${DAPPS_SERVICES[@]}"
# Recreate RPC so reserved-peers / config bind-mount changes apply after sync.
docker compose "${COMPOSE_ARGS[@]}" up -d --force-recreate openethereum

if [ "${SKIP_HEALTH}" = false ]; then
  remote_health_check_dapps
fi

echo "DApps deploy complete."
