#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADDR_FILE="${ROOT_DIR}/genesis/contract-addresses.json"
OUT="${ROOT_DIR}/envs/validator-app.env"

if [ ! -f "${ADDR_FILE}" ]; then
  echo "Missing ${ADDR_FILE}. Run bootstrap-chain.sh first." >&2
  exit 1
fi

CONSENSUS_PROXY="$(jq -r .consensusProxy "${ADDR_FILE}")"
BLOCK_REWARD_PROXY="$(jq -r .blockRewardProxy "${ADDR_FILE}")"

cat > "${OUT}" <<EOF
CONSENSUS_PROXY=${CONSENSUS_PROXY}
BLOCK_REWARD_PROXY=${BLOCK_REWARD_PROXY}
EOF

echo "Wrote ${OUT}"
