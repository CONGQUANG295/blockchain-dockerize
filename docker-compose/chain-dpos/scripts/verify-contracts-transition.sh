#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACTS_DIR="${ROOT_DIR}/../../../blockchain-docker-base/resources/icsc-dpos-contracts"
GENESIS_DIR="${ROOT_DIR}/genesis"
ENVS_DIR="${ROOT_DIR}/envs"
RPC_URL="${DPOS_RPC_URL:-http://127.0.0.1:8545}"
ADDRESSES_FILE="${GENESIS_DIR}/contract-addresses.json"

set -a
# shellcheck disable=SC1090
source "${ENVS_DIR}/dpos.chain.env"
set +a

CONSENSUS="$(node -e "console.log(JSON.parse(require('fs').readFileSync('${ADDRESSES_FILE}','utf8')).consensusProxy)")"
REWARD="$(node -e "console.log(JSON.parse(require('fs').readFileSync('${ADDRESSES_FILE}','utf8')).blockRewardProxy)")"
VALIDATOR="$(cat "${GENESIS_DIR}/validator-1.address")"
TRANSITION="${CONTRACT_TRANSITION_BLOCK}"

wait_for_block() {
  while true; do
    BLOCK_HEX="$(curl -sf -X POST -H "Content-Type: application/json" \
      --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
      "${RPC_URL}" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).result))")"
    BLOCK_DEC=$((16#${BLOCK_HEX#0x}))
    echo "Current block: ${BLOCK_DEC} (waiting for >= ${TRANSITION})"
    if [ "${BLOCK_DEC}" -ge "${TRANSITION}" ]; then
      return 0
    fi
    sleep 2
  done
}

eth_call() {
  local to="$1"
  local data="$2"
  curl -sf -X POST -H "Content-Type: application/json" \
    --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"to\":\"${to}\",\"data\":\"${data}\"},\"latest\"],\"id\":1}" \
    "${RPC_URL}" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).result))")"
}

wait_for_block

# getValidators() selector
VALIDATORS_DATA="$(eth_call "${CONSENSUS}" "0x5f48ea35")"
if [ "${VALIDATORS_DATA}" = "0x" ] || [ -z "${VALIDATORS_DATA}" ]; then
  echo "Consensus.getValidators() returned empty" >&2
  exit 1
fi

VALIDATOR_CLEAN="${VALIDATOR#0x}"
if ! echo "${VALIDATORS_DATA}" | grep -qi "${VALIDATOR_CLEAN}"; then
  echo "Validator ${VALIDATOR} not found in getValidators() result: ${VALIDATORS_DATA}" >&2
  exit 1
fi

# INFLATION() on BlockReward — public getter
INFLATION_DATA="$(eth_call "${REWARD}" "0x0f9c3bde")"
if [ "${INFLATION_DATA}" = "0x" ] || [ -z "${INFLATION_DATA}" ]; then
  echo "BlockReward.INFLATION() call failed" >&2
  exit 1
fi

echo "Transition verified at block >= ${TRANSITION}"
echo "  consensus: ${CONSENSUS}"
echo "  blockReward: ${REWARD}"
echo "  validator present in getValidators()"
