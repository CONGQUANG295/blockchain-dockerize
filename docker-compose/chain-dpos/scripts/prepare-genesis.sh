#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/paths.sh
source "${ROOT_DIR}/scripts/lib/paths.sh"
chain_dpos_paths "${ROOT_DIR}"
chain_dpos_ensure_node_dirs

CONTRACTS_DIR="${ROOT_DIR}/../../../blockchain-docker-base/resources/dpos-contracts"
ENVS_DIR="${ROOT_DIR}/envs"

for f in dpos.chain.env dpos.contract.env; do
  if [ ! -f "${ENVS_DIR}/${f}" ]; then
    cp "${ENVS_DIR}/${f}.example" "${ENVS_DIR}/${f}"
    echo "Created ${ENVS_DIR}/${f} from example — edit required fields before re-run."
    exit 1
  fi
done

set -a
# shellcheck disable=SC1090
source "${ENVS_DIR}/dpos.chain.env"
# shellcheck disable=SC1090
source "${ENVS_DIR}/dpos.contract.env"
set +a

require_var() {
  if [ -z "${!1:-}" ]; then
    echo "Missing required env: $1" >&2
    exit 1
  fi
}

require_var NETWORK_NAME
require_var NETWORK_ID
require_var PREMINE_ADDRESS
require_var PREMINE_BALANCE_WEI
require_var VALIDATOR_BALANCE_WEI
require_var CONTRACT_TRANSITION_BLOCK
require_var BLOCK_TIME_SECONDS

if ! [[ "${NETWORK_ID}" =~ ^0x[0-9a-fA-F]+$ ]]; then
  echo "NETWORK_ID must be hex (e.g. 0x3a1)" >&2
  exit 1
fi

echo "Generating contract constants..."
DPOS_CONTRACT_ENV="${ENVS_DIR}/dpos.contract.env" \
  node "${CONTRACTS_DIR}/scripts/generate-contract-config.js"

echo "Generating validator keystore..."
VALIDATOR_1_ADDRESS="$("${ROOT_DIR}/scripts/gen-validator-account.sh" "${PATH_NODE_VALIDATOR}")"

VALIDATOR_1_ADDRESS="$(echo "${VALIDATOR_1_ADDRESS}" | tr '[:upper:]' '[:lower:]')"
PREMINE_LC="$(echo "${PREMINE_ADDRESS}" | tr '[:upper:]' '[:lower:]')"

if [ "${VALIDATOR_1_ADDRESS}" = "${PREMINE_LC}" ]; then
  echo "PREMINE_ADDRESS must differ from VALIDATOR_1_ADDRESS" >&2
  exit 1
fi

echo "${VALIDATOR_1_ADDRESS}" > "${PATH_VALIDATOR_ADDRESS}"
export VALIDATOR_1_ADDRESS

echo "Generating spec.json phase-1..."
node "${CONTRACTS_DIR}/scripts/generate-spec.js" \
  --phase=1 \
  --env "${ENVS_DIR}/dpos.chain.env" \
  --validator "${VALIDATOR_1_ADDRESS}" \
  --out "${PATH_SPEC}"

cp "${PATH_SPEC}" "${PATH_GENESIS}/spec.phase-1.json"

"${ROOT_DIR}/scripts/prepare-envs-validator-1.sh"

echo "Genesis ready:"
echo "  validator: ${VALIDATOR_1_ADDRESS}"
echo "  spec:      ${PATH_SPEC}"
echo "  node:      ${PATH_NODE_VALIDATOR}/"
