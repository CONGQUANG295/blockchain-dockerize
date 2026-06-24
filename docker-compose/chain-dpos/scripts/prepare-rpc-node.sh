#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/paths.sh
source "${ROOT_DIR}/scripts/lib/paths.sh"
chain_dpos_paths "${ROOT_DIR}"
chain_dpos_ensure_node_dirs

if [ ! -f "${PATH_VALIDATOR_ENODE}" ]; then
  echo "Missing ${PATH_VALIDATOR_ENODE}. Run get_enode.sh after bootstrap." >&2
  exit 1
fi

cp "${PATH_TEMPLATES}/rpc.toml.template" "${PATH_RPC_CONFIG}"
cp "${PATH_VALIDATOR_ENODE}" "${PATH_RESERVED_PEERS}"
echo "Wrote ${PATH_RPC_CONFIG}"
echo "Wrote ${PATH_RESERVED_PEERS}"
