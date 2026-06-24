#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVS_DIR="${ROOT_DIR}/envs"
CONFIG_DIR="${ROOT_DIR}/config"
GENESIS_DIR="${ROOT_DIR}/genesis"

if [ ! -f "${ENVS_DIR}/validator-1.env" ]; then
  cp "${ENVS_DIR}/validator-1.env.example" "${ENVS_DIR}/validator-1.env"
fi

VALIDATOR_ADDRESS=""
if [ -f "${GENESIS_DIR}/validator-1.address" ]; then
  VALIDATOR_ADDRESS="$(cat "${GENESIS_DIR}/validator-1.address")"
fi

if [ -z "${VALIDATOR_ADDRESS}" ]; then
  echo "Run prepare-genesis.sh first (missing genesis/validator-1.address)" >&2
  exit 1
fi

sed "s/__VALIDATOR_ADDRESS__/${VALIDATOR_ADDRESS}/g" \
  "${CONFIG_DIR}/validator-1.toml.template" > "${CONFIG_DIR}/validator-1.toml"

cat > "${ENVS_DIR}/validator-1.env" <<EOF
VALIDATOR_ADDRESS=${VALIDATOR_ADDRESS}
SPEC_PATH=./genesis/spec.json
OE_CONFIG_PATH=./config/validator-1.toml
EOF

echo "Prepared validator-1 config for ${VALIDATOR_ADDRESS}"
