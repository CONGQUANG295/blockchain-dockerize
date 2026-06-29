#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVS_DIR="${ROOT_DIR}/envs"
GENESIS_DIR="${ROOT_DIR}/genesis"
RPC_URL="${DPOS_RPC_URL:-http://127.0.0.1:8545}"
THRESHOLD="${SUPPLY_CAP_THRESHOLD:-95}"
ADDRESSES_FILE="${GENESIS_DIR}/contract-addresses.json"

set -a
# shellcheck disable=SC1090
source "${ENVS_DIR}/dpos.chain.env"
set +a

: "${MAX_SUPPLY_WEI:?MAX_SUPPLY_WEI required in dpos.chain.env}"

if [ ! -f "${ADDRESSES_FILE}" ]; then
  echo "Missing ${ADDRESSES_FILE}" >&2
  exit 1
fi

REWARD="$(node -e "console.log(JSON.parse(require('fs').readFileSync('${ADDRESSES_FILE}','utf8')).blockRewardProxy)")"
GET_TOTAL_SUPPLY_SELECTOR="0xc4e41b22"

response="$(curl -sf -X POST -H "Content-Type: application/json" \
  --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"to\":\"${REWARD}\",\"data\":\"${GET_TOTAL_SUPPLY_SELECTOR}\",\"gas\":\"0x2faf080\"},\"latest\"],\"id\":1}" \
  "${RPC_URL}")"

result="$(echo "${response}" | jq -r '.result // empty')"
if [ -z "${result}" ] || [ "${result}" = "null" ]; then
  echo "getTotalSupply() failed: ${response}" >&2
  exit 1
fi

total=$((16#${result#0x}))
max="${MAX_SUPPLY_WEI}"
pct=$(( total * 100 / max ))

echo "Supply: ${total} / ${max} (${pct}%)"

if [ "${pct}" -ge "${THRESHOLD}" ]; then
  echo "Supply cap threshold reached (>= ${THRESHOLD}%)" >&2
  exit 1
fi

echo "check-supply-cap: OK"
