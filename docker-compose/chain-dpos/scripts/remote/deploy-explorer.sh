#!/usr/bin/env bash
# Server-side: deploy Blockscout v11 explorer only (no netstats-dashboard / docs / faucet).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib.sh
source "${ROOT_DIR}/scripts/remote/lib.sh"

WITH_TRAEFIK=true
SKIP_HEALTH=false

# Blockscout v11 + RPC archive node + Traefik (explorer domains only).
EXPLORER_SERVICES=(
  traefik
  openethereum
  db-init
  db
  redis-db
  backend
  frontend
  stats-db-init
  stats-db
  stats
  visualizer
)

usage() {
  cat <<'EOF'
Usage: ./scripts/remote/deploy-explorer.sh [options]

Deploy Blockscout v11 explorer + RPC archive node. Does not start netstats-dashboard,
docs-static, or eth-faucet — use deploy-dapps.sh on the DApps server for those.

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

echo "=== Prepare RPC node + explorer env ==="
./scripts/prepare-rpc-node.sh
WITH_TRAEFIK_PREPARE=$([ "${WITH_TRAEFIK}" = true ] && echo true || echo false) \
  ./scripts/prepare-envs-dapps.sh

set -a
# shellcheck disable=SC1090
source envs/db.env
source envs/blockscout-stats.env
source envs/deploy.env
set +a

mapfile -t COMPOSE_ARGS < <(remote_explorer_compose_args "${ROOT_DIR}")
if [ "${EXPLORER_CUSTOM_PROFILE:-}" = "gtbs" ]; then
  echo "GTBS explorer profile enabled (GitHub assets + SKIP_ENVS_VALIDATION)"
fi

echo "=== Pull + start explorer stack (no netstats-dashboard) ==="
docker compose "${COMPOSE_ARGS[@]}" pull "${EXPLORER_SERVICES[@]}"
remote_ensure_postgres_data_permissions "${COMPOSE_ARGS[@]}"
# Restart DB if already running — picks up fixed bind-mount permissions
docker compose "${COMPOSE_ARGS[@]}" restart db stats-db 2>/dev/null || true
docker compose "${COMPOSE_ARGS[@]}" up -d "${EXPLORER_SERVICES[@]}"

if [ "${SKIP_HEALTH}" = false ]; then
  ./scripts/health-check.sh
fi

echo "Explorer deploy complete."
