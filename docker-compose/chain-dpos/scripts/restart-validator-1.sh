#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVS_DIR="${ROOT_DIR}/envs"
RPC_URL="${DPOS_RPC_URL:-http://127.0.0.1:8545}"

set -a
# shellcheck disable=SC1090
source "${ENVS_DIR}/dpos.chain.env"
set +a

BLOCK_HEX="$(curl -sf -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  "${RPC_URL}" | jq -r '.result')"
BLOCK_DEC=$((16#${BLOCK_HEX#0x}))
TRANSITION="${CONTRACT_TRANSITION_BLOCK}"

if [ "${BLOCK_DEC}" -ge "${TRANSITION}" ]; then
  echo "Current block ${BLOCK_DEC} >= transition ${TRANSITION}; too late to restart safely" >&2
  exit 1
fi

docker compose -f "${ROOT_DIR}/compose-validator-1.yml" restart openethereum
echo "Restarted openethereum at block ${BLOCK_DEC}"
