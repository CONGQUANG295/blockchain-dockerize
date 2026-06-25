#!/usr/bin/env bash
# Server-side: bootstrap validator-1 chain + validator-app (images from Docker Hub).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib.sh
source "${ROOT_DIR}/scripts/remote/lib.sh"

SKIP_BOOTSTRAP=false
SKIP_HEALTH=false
WITH_TRAEFIK=false
START_ONLY=false

usage() {
  cat <<'EOF'
Usage: ./scripts/remote/deploy-validator.sh [options]

Bootstrap chain (phases B–F) and start validator-1 + validator-app.
Genesis (phase A) must already exist — run prepare-deploy.sh on operator machine first.

Options:
  --skip-bootstrap   Chain already bootstrapped; only pull + start validator stack
  --start-only       Alias for --skip-bootstrap
  --with-traefik     Pass --with-traefik to render-envs (for shared deploy.env)
  --skip-health      Skip health-check.sh after start
  -h, --help         Show this help

Requires: envs/deploy.env with DOCKERHUB_NAMESPACE, genesis/ from local sync.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-bootstrap|--start-only) SKIP_BOOTSTRAP=true ;;
    --with-traefik) WITH_TRAEFIK=true ;;
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

RENDER_ARGS=()
[ "${WITH_TRAEFIK}" = true ] && RENDER_ARGS+=(--with-traefik)

echo "=== Render env + images (Docker Hub: ${DOCKERHUB_NAMESPACE}) ==="
./scripts/render-envs.sh envs/deploy.env "${RENDER_ARGS[@]}"

if [ "${SKIP_BOOTSTRAP}" = false ]; then
  echo "=== Bootstrap chain (skip genesis — prepared locally) ==="
  ./scripts/bootstrap-chain.sh --skip-genesis
  ./scripts/export-validator-app-env.sh
else
  if [ ! -f envs/validator-app.env ]; then
    ./scripts/export-validator-app-env.sh
  fi
fi

set -a
# shellcheck disable=SC1090
source envs/validator-app.env
set +a

echo "=== Pull + start validator-1 + validator-app ==="
# shellcheck source=lib/compose.sh
source "${ROOT_DIR}/scripts/lib/compose.sh"
chain_dpos_compose "${ROOT_DIR}" -f compose-validator-1.yml --profile consensus pull
chain_dpos_compose "${ROOT_DIR}" -f compose-validator-1.yml --profile consensus up -d

if [ "${SKIP_HEALTH}" = false ]; then
  remote_wait_for_rpc
  if [ "${OPEN_P2P_PORT:-}" = "1" ] || [ "${OPEN_P2P_PORT:-}" = "true" ]; then
    echo "=== Open P2P firewall ==="
    sudo OPEN_P2P_PORT=1 P2P_PORT="${P2P_PORT:-30300}" ./scripts/remote/open-p2p-port.sh
  fi
  echo "=== Export peer bundle (spec + enode + reserved-peers) ==="
  ./scripts/export-peer-config.sh
  echo "Validator deploy complete."
  echo "  reserved-peers: $(cat genesis/reserved-peers.txt 2>/dev/null | head -1 || echo 'run export-peer-config.sh')"
else
  echo "Validator stack started (--skip-health)."
fi
