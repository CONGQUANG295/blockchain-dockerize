#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/paths.sh
source "${ROOT_DIR}/scripts/lib/paths.sh"
chain_dpos_paths "${ROOT_DIR}"
chain_dpos_ensure_node_dirs

ENVS_DIR="${ROOT_DIR}/envs"

if [ ! -f "${ENVS_DIR}/validator-1.env" ]; then
  cp "${ENVS_DIR}/validator-1.env.example" "${ENVS_DIR}/validator-1.env"
fi

VALIDATOR_ADDRESS=""
if [ -f "${PATH_VALIDATOR_ADDRESS}" ]; then
  VALIDATOR_ADDRESS="$(cat "${PATH_VALIDATOR_ADDRESS}")"
fi

if [ -z "${VALIDATOR_ADDRESS}" ]; then
  echo "Run prepare-genesis.sh first (missing ${PATH_VALIDATOR_ADDRESS})" >&2
  exit 1
fi

sed "s/__VALIDATOR_ADDRESS__/${VALIDATOR_ADDRESS}/g" \
  "${PATH_TEMPLATES}/validator-1.toml.template" > "${PATH_VALIDATOR_CONFIG}"

cat > "${ENVS_DIR}/validator-1.env" <<EOF
VALIDATOR_ADDRESS=${VALIDATOR_ADDRESS}
SPEC_PATH=./genesis/spec.json
OE_CONFIG_PATH=./nodes/validator-1/config.toml
EOF

echo "Prepared validator-1 config for ${VALIDATOR_ADDRESS}"
