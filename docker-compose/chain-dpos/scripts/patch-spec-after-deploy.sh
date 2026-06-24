#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACTS_DIR="${ROOT_DIR}/../../../blockchain-docker-base/resources/dpos-contracts"
GENESIS_DIR="${ROOT_DIR}/genesis"
ENVS_DIR="${ROOT_DIR}/envs"
ADDRESSES_FILE="${GENESIS_DIR}/contract-addresses.json"

if [ ! -f "${ADDRESSES_FILE}" ]; then
  echo "Missing ${ADDRESSES_FILE} — run deploy first" >&2
  exit 1
fi

# GTBS custom staking uses the same keys: consensusProxy, blockRewardProxy (+ stakingVault in JSON)

CONSENSUS="$(node -e "console.log(JSON.parse(require('fs').readFileSync('${ADDRESSES_FILE}','utf8')).consensusProxy)")"
REWARD="$(node -e "console.log(JSON.parse(require('fs').readFileSync('${ADDRESSES_FILE}','utf8')).blockRewardProxy)")"
TRANSITION="$(grep -E '^CONTRACT_TRANSITION_BLOCK=' "${ENVS_DIR}/dpos.chain.env" | cut -d= -f2)"

if [ -z "${CONSENSUS}" ] || [ -z "${REWARD}" ] || [ -z "${TRANSITION}" ]; then
  echo "Failed to read deploy addresses or CONTRACT_TRANSITION_BLOCK" >&2
  exit 1
fi

if [ ! -f "${GENESIS_DIR}/spec.phase-1.json" ]; then
  cp "${GENESIS_DIR}/spec.json" "${GENESIS_DIR}/spec.phase-1.json"
fi

node "${CONTRACTS_DIR}/scripts/generate-spec.js" \
  --phase=2 \
  --in "${GENESIS_DIR}/spec.json" \
  --consensus "${CONSENSUS}" \
  --reward "${REWARD}" \
  --transition "${TRANSITION}" \
  --out "${GENESIS_DIR}/spec.json"

echo "Patched spec.json with contracts at block ${TRANSITION}"
