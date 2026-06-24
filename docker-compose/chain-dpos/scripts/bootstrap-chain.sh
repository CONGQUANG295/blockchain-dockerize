#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

wait_for_rpc() {
  local url="${1:-http://127.0.0.1:8545}"
  echo "Waiting for RPC at ${url}..."
  for _ in $(seq 1 60); do
    if curl -sf -X POST -H "Content-Type: application/json" \
      --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
      "${url}" >/dev/null 2>&1; then
      echo "RPC ready"
      return 0
    fi
    sleep 2
  done
  echo "RPC not ready" >&2
  exit 1
}

echo "=== Phase A: prepare genesis ==="
./scripts/prepare-genesis.sh

export VALIDATOR_1_ADDRESS="$(cat genesis/validator-1.address)"
set -a
# shellcheck disable=SC1090
source envs/dpos.chain.env
set +a

echo "=== Phase B: start validator-1 ==="
docker compose -f compose-validator-1.yml up -d openethereum netstats-api
wait_for_rpc

echo "=== Phase C: deploy contracts ==="
set -a
# shellcheck disable=SC1090
source envs/deploy.env 2>/dev/null || true
set +a
COMPOSE_PROJECT_NAME=dpos-validator-1 docker compose -f compose-deploy-contracts.yml run --rm \
  -e "ENABLE_CUSTOM_STAKING=${ENABLE_CUSTOM_STAKING:-false}" \
  deployer

echo "=== Phase D: patch spec + restart ==="
./scripts/patch-spec-after-deploy.sh
./scripts/restart-validator-1.sh
wait_for_rpc

echo "=== Phase E: verify transition ==="
./scripts/verify-contracts-transition.sh

echo "=== Phase F: export enode ==="
./scripts/get_enode.sh

echo "Bootstrap complete. Optional: docker compose -f compose-validator-1.yml --profile consensus up -d validator-app"
