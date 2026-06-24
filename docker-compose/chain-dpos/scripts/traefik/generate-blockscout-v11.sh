#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ROUTE_TEMPLATE="${ROOT_DIR}/traefik/dynamic/blockscout-v11.yml.template"
ROUTE_OUTPUT="${ROOT_DIR}/traefik/dynamic/blockscout-v11.yml"
MW_TEMPLATE="${ROOT_DIR}/traefik/dynamic/middlewares.yml.template"
MW_OUTPUT="${ROOT_DIR}/traefik/dynamic/middlewares.yml"
ENV_FILE="${ROOT_DIR}/envs/traefik.env"

if [ ! -f "${ENV_FILE}" ]; then
  echo "Missing ${ENV_FILE}. Run render-envs.sh first." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

: "${EXPLORER_SERVER_NAME:?Set EXPLORER_SERVER_NAME in envs/traefik.env}"
: "${STATS_SERVER_NAME:?Set STATS_SERVER_NAME in envs/traefik.env}"
: "${VISUALIZE_SERVER_NAME:?Set VISUALIZE_SERVER_NAME in envs/traefik.env}"
NETWORK_TYPE="${NETWORK_TYPE:-testnet}"

export EXPLORER_SERVER_NAME STATS_SERVER_NAME VISUALIZE_SERVER_NAME NETWORK_TYPE

envsubst '${EXPLORER_SERVER_NAME} ${STATS_SERVER_NAME} ${VISUALIZE_SERVER_NAME} ${NETWORK_TYPE}' \
  < "${ROUTE_TEMPLATE}" > "${ROUTE_OUTPUT}"

envsubst '${EXPLORER_SERVER_NAME}' \
  < "${MW_TEMPLATE}" > "${MW_OUTPUT}"

echo "Generated ${ROUTE_OUTPUT}"
echo "Generated ${MW_OUTPUT}"
