#!/usr/bin/env bash
# Wait until OpenEthereum JSON-RPC responds to eth_blockNumber.
# Usage: source scripts/wait-for-rpc.sh && wait_for_rpc [url]

wait_for_rpc() {
  local url="${1:-http://127.0.0.1:8545}"
  local max="${RPC_WAIT_ATTEMPTS:-180}"
  local interval="${RPC_WAIT_INTERVAL:-2}"

  echo "Waiting for RPC at ${url} (up to $((max * interval))s)..."
  for i in $(seq 1 "${max}"); do
    if curl -sf -X POST -H "Content-Type: application/json" \
      --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
      "${url}" >/dev/null 2>&1; then
      echo "RPC ready"
      return 0
    fi
    if [ $((i % 15)) -eq 0 ]; then
      echo "  still waiting... (${i}/${max})"
    fi
    sleep "${interval}"
  done

  echo "RPC not ready at ${url}" >&2
  echo "Check: docker compose -f compose-validator-1.yml logs openethereum --tail=50" >&2
  return 1
}
