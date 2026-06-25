#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"
# shellcheck source=wait-for-rpc.sh
source "${ROOT_DIR}/scripts/wait-for-rpc.sh"

SKIP_GENESIS=false

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-genesis) SKIP_GENESIS=true ;;
    -h|--help)
      echo "Usage: $0 [--skip-genesis]"
      echo "  --skip-genesis  Skip Phase A (genesis already prepared on operator machine)"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

if [ "${SKIP_GENESIS}" = true ]; then
  if [ ! -f genesis/validator-1.address ]; then
    echo "Missing genesis/validator-1.address — run prepare-genesis.sh locally or omit --skip-genesis" >&2
    exit 1
  fi
  echo "=== Phase A: skipped (genesis prepared) ==="
else
  echo "=== Phase A: prepare genesis ==="
  ./scripts/prepare-genesis.sh
fi

export VALIDATOR_1_ADDRESS="$(cat genesis/validator-1.address)"
set -a
# shellcheck disable=SC1090
source envs/dpos.chain.env
set +a

echo "=== Phase B: start validator-1 ==="
# shellcheck source=lib/compose.sh
source "${ROOT_DIR}/scripts/lib/compose.sh"
chain_dpos_compose "${ROOT_DIR}" -f compose-validator-1.yml up -d openethereum netstats-api
wait_for_rpc

echo "=== Phase C: deploy contracts ==="
set -a
# shellcheck disable=SC1090
source envs/deploy.env 2>/dev/null || true
# shellcheck disable=SC1090
source envs/images.env
# shellcheck disable=SC1090
source envs/dpos.chain.env
set +a
export VALIDATOR_1_ADDRESS
COMPOSE_PROJECT_NAME=dpos-validator-1 docker compose \
  --env-file envs/images.env \
  --env-file envs/dpos.chain.env \
  -f compose-deploy-contracts.yml run --rm \
  -e "ENABLE_CUSTOM_STAKING=${ENABLE_CUSTOM_STAKING:-false}" \
  -e "VALIDATOR_KEYSTORE_DIR=/app/keys" \
  -e "VALIDATOR_PASSWORD_FILE=/app/secrets/node.pwd" \
  deployer

echo "=== Phase D: patch spec + restart ==="
./scripts/patch-spec-after-deploy.sh
./scripts/restart-validator-1.sh
wait_for_rpc

echo "=== Phase E: verify transition ==="
./scripts/verify-contracts-transition.sh

echo "=== Phase F: export peer config ==="
./scripts/export-peer-config.sh

echo "Bootstrap complete. Optional: docker compose -f compose-validator-1.yml --profile consensus up -d validator-app"
