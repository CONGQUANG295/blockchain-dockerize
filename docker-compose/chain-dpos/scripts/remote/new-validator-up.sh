#!/usr/bin/env bash
# Server: docker compose up for a non-seed validator node.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/compose.sh
source "${ROOT_DIR}/scripts/lib/compose.sh"

NODE_ID="${NODE_ID:-}"
AUTO_PREPARE=true
SKIP_PULL=false

usage() {
  cat <<'EOF'
Usage: NODE_ID=validator-N ./scripts/remote/new-validator-up.sh [options]

Options:
  --no-prepare    Do not run prepare-new-validator.sh if compose file missing
  --skip-pull     Skip docker compose pull
  -h, --help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --no-prepare) AUTO_PREPARE=false ;;
    --skip-pull) SKIP_PULL=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

if [ -z "${NODE_ID}" ]; then
  echo "NODE_ID is required." >&2
  usage
  exit 1
fi

cd "${ROOT_DIR}"
COMPOSE_FILE="compose-${NODE_ID}.yml"

if [ ! -f "${COMPOSE_FILE}" ]; then
  if [ "${AUTO_PREPARE}" = true ]; then
    NODE_ID="${NODE_ID}" ./scripts/remote/prepare-new-validator.sh
  else
    echo "Missing ${COMPOSE_FILE} — run prepare-new-validator.sh first." >&2
    exit 1
  fi
fi

if [ "${SKIP_PULL}" = false ]; then
  echo "=== Pull images ==="
  chain_dpos_compose "${ROOT_DIR}" -f "${COMPOSE_FILE}" pull
fi

echo "=== Start ${NODE_ID} ==="
chain_dpos_compose "${ROOT_DIR}" -f "${COMPOSE_FILE}" up -d

echo ""
echo "Validator ${NODE_ID} up."
echo "  logs: docker logs -f dpos-\$(grep NETWORK_TYPE envs/dpos.chain.env | cut -d= -f2)-${NODE_ID} 2>/dev/null || docker compose -f ${COMPOSE_FILE} logs -f --tail=100"
echo "  RPC:  curl -s -X POST -H 'Content-Type: application/json' --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}' http://127.0.0.1:8545 | jq ."
