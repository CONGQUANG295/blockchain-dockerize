#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GTBS="${ROOT_DIR}/../../../blockchain-docker-base/resources/custom-staking-contracts"
# shellcheck source=lib/wei-math.sh
source "${ROOT_DIR}/scripts/lib/wei-math.sh"

for f in dpos.chain.env dpos.contract.env gtbs-staking.env; do
  if [ ! -f "${ROOT_DIR}/envs/${f}" ]; then
    echo "Missing ${ROOT_DIR}/envs/${f} — run render-envs.sh first" >&2
    exit 1
  fi
done

set -a
# shellcheck disable=SC1090
source "${ROOT_DIR}/envs/dpos.chain.env"
# shellcheck disable=SC1090
source "${ROOT_DIR}/envs/dpos.contract.env"
# shellcheck disable=SC1090
source "${ROOT_DIR}/envs/gtbs-staking.env"
set +a

: "${PREMINE_BALANCE_WEI:?PREMINE_BALANCE_WEI required}"
: "${MAX_SUPPLY_WEI:?MAX_SUPPLY_WEI required}"
: "${BLOCK_TIME_SECONDS:?BLOCK_TIME_SECONDS required}"

EXPECTED_BPY=$(( 31536000 / BLOCK_TIME_SECONDS ))
if [ $(( 31536000 % BLOCK_TIME_SECONDS )) -ne 0 ]; then
  echo "BLOCK_TIME_SECONDS must divide 31536000 evenly" >&2
  exit 1
fi

if ! wei_gt "${MAX_SUPPLY_WEI}" "${PREMINE_BALANCE_WEI}"; then
  echo "MAX_SUPPLY_WEI must exceed PREMINE_BALANCE_WEI" >&2
  exit 1
fi

EXPECTED_ISG="$(wei_div_gwei "${PREMINE_BALANCE_WEI}")"
if [ "${INITIAL_SUPPLY_GWEI:-}" != "${EXPECTED_ISG}" ]; then
  echo "INITIAL_SUPPLY_GWEI mismatch: got ${INITIAL_SUPPLY_GWEI:-unset}, want ${EXPECTED_ISG}" >&2
  exit 1
fi

if [ "${BLOCKS_PER_YEAR:-}" != "${EXPECTED_BPY}" ]; then
  echo "BLOCKS_PER_YEAR mismatch: got ${BLOCKS_PER_YEAR:-unset}, want ${EXPECTED_BPY}" >&2
  exit 1
fi

BR="${GTBS}/contracts/BlockReward.sol"
if [ ! -f "${BR}" ]; then
  echo "Missing ${BR}" >&2
  exit 1
fi

grep -q "BLOCKS_PER_YEAR = ${EXPECTED_BPY}" "${BR}" || {
  echo "BlockReward.sol BLOCKS_PER_YEAR not patched to ${EXPECTED_BPY}. Run generate-gtbs-contract-config.js first." >&2
  exit 1
}
grep -q "MAX_SUPPLY = ${MAX_SUPPLY_WEI}" "${BR}" || {
  echo "BlockReward.sol MAX_SUPPLY not patched to ${MAX_SUPPLY_WEI}" >&2
  exit 1
}

echo "validate-tokenomics: OK (blocksPerYear=${EXPECTED_BPY}, maxSupply=${MAX_SUPPLY_WEI})"
