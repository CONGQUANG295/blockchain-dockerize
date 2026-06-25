#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/compose.sh
source "${ROOT_DIR}/scripts/lib/compose.sh"

NODE_ID="${NODE_ID:-}"

if [ -z "${NODE_ID}" ]; then
  echo "NODE_ID is required." >&2
  exit 1
fi

cd "${ROOT_DIR}"
COMPOSE_FILE="compose-${NODE_ID}.yml"

if [ ! -f "${COMPOSE_FILE}" ]; then
  echo "Missing ${COMPOSE_FILE}" >&2
  exit 1
fi

chain_dpos_compose "${ROOT_DIR}" -f "${COMPOSE_FILE}" down
echo "Stopped ${NODE_ID}."
