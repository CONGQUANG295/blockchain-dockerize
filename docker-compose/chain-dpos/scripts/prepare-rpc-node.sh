#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENODE_FILE="${ROOT_DIR}/genesis/validator-1.enode"
TEMPLATE="${ROOT_DIR}/config/rpc.toml.template"
OUT="${ROOT_DIR}/config/rpc.toml"

if [ ! -f "${ENODE_FILE}" ]; then
  echo "Missing ${ENODE_FILE}. Run get_enode.sh after bootstrap." >&2
  exit 1
fi

ENODE="$(tr -d '\n' < "${ENODE_FILE}")"
sed "s|__VALIDATOR_1_ENODE__|${ENODE}|g" "${TEMPLATE}" > "${OUT}"
echo "Wrote ${OUT}"
