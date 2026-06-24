#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMEOUT="${HEALTH_CHECK_TIMEOUT:-180}"
INTERVAL=5

set -a
# shellcheck disable=SC1090
source "${ROOT_DIR}/envs/dpos.chain.env"
set +a

RPC_CONTAINER="dpos-${NETWORK_TYPE:-testnet}-rpc"
VALIDATOR_CONTAINER="dpos-${NETWORK_TYPE:-testnet}-validator-1"

rpc_call() {
  local container="$1"
  local method="$2"
  docker exec "${container}" sh -c \
    "curl -sf -X POST -H 'Content-Type: application/json' \
    --data '{\"jsonrpc\":\"2.0\",\"method\":\"${method}\",\"params\":[],\"id\":1}' \
    http://127.0.0.1:8545" 2>/dev/null || true
}

hex_to_dec() {
  python3 -c "print(int('${1#0x}', 16))" 2>/dev/null || echo 0
}

echo "Health-check: waiting for RPC node sync (timeout ${TIMEOUT}s)..."
elapsed=0
while [ "${elapsed}" -lt "${TIMEOUT}" ]; do
  syncing="$(rpc_call "${RPC_CONTAINER}" eth_syncing)"
  if echo "${syncing}" | grep -q '"result":false'; then
    rpc_block="$(rpc_call "${RPC_CONTAINER}" eth_blockNumber | sed -n 's/.*"result":"\(0x[^"]*\)".*/\1/p')"
    val_block="$(rpc_call "${VALIDATOR_CONTAINER}" eth_blockNumber | sed -n 's/.*"result":"\(0x[^"]*\)".*/\1/p')"
    if [ -n "${rpc_block}" ] && [ -n "${val_block}" ]; then
      rpc_dec="$(hex_to_dec "${rpc_block}")"
      val_dec="$(hex_to_dec "${val_block}")"
      diff=$((val_dec - rpc_dec))
      if [ "${diff#-}" -le 2 ]; then
        echo "RPC synced at block ${rpc_dec} (validator ${val_dec})"
        break
      fi
    fi
  fi
  sleep "${INTERVAL}"
  elapsed=$((elapsed + INTERVAL))
done

if [ "${elapsed}" -ge "${TIMEOUT}" ]; then
  echo "RPC node did not sync in time" >&2
  exit 1
fi

if docker ps --format '{{.Names}}' | grep -q '^blockscout-backend$'; then
  echo "Health-check: Blockscout backend API..."
  for _ in $(seq 1 30); do
    if docker exec blockscout-backend sh -c 'curl -sf http://127.0.0.1:4000/api/v2/stats >/dev/null'; then
      echo "Blockscout API ready"
      exit 0
    fi
    sleep 5
  done
  echo "Blockscout API not ready" >&2
  exit 1
fi

echo "Health-check passed (RPC only; blockscout not running)"
exit 0
