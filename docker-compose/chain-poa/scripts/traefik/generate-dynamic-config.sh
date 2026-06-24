#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHAIN_POA_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEMPLATE="${CHAIN_POA_DIR}/traefik/dynamic/blockscout-v5.yml.template"
OUTPUT="${CHAIN_POA_DIR}/traefik/dynamic/blockscout-v5.yml"
ENV_FILE="${CHAIN_POA_DIR}/envs/traefik.env"

cd "${CHAIN_POA_DIR}"

if [ ! -f "${ENV_FILE}" ]; then
  echo "Missing ${ENV_FILE}. Run ./scripts/traefik/prepare-envs-traefik.sh first." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

: "${BLOCKSCOUT_FRONT_SERVER_NAME:?Set BLOCKSCOUT_FRONT_SERVER_NAME in envs/traefik.env}"
: "${NETWORK_TYPE:=mainnet}"

export BLOCKSCOUT_FRONT_SERVER_NAME NETWORK_TYPE

envsubst '${BLOCKSCOUT_FRONT_SERVER_NAME} ${NETWORK_TYPE}' < "${TEMPLATE}" > "${OUTPUT}"

echo "Generated ${OUTPUT}"
