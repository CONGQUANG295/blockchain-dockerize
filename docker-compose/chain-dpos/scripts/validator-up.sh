#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/compose.sh
source "${ROOT_DIR}/scripts/lib/compose.sh"

cd "${ROOT_DIR}"

./scripts/export-validator-app-env.sh

set -a
# shellcheck disable=SC1090
source envs/validator-app.env
set +a

chain_dpos_compose "${ROOT_DIR}" -f compose-validator-1.yml --profile consensus pull
chain_dpos_compose "${ROOT_DIR}" -f compose-validator-1.yml --profile consensus up -d

echo "Validator stack up (openethereum + netstats-api + validator-app)"
