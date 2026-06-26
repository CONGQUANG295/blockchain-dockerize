#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/paths.sh
source "${ROOT_DIR}/scripts/lib/paths.sh"
# shellcheck source=lib/peer-config.sh
source "${ROOT_DIR}/scripts/lib/peer-config.sh"
peer_config_paths "${ROOT_DIR}"
peer_config_ensure_dirs

if [ ! -f "${PATH_GENESIS_RESERVED_PEERS}" ]; then
  if [ -f "${PATH_VALIDATOR_ENODE}" ]; then
    "${ROOT_DIR}/scripts/export-peer-config.sh" --skip-enode-refresh
  else
    echo "Missing ${PATH_GENESIS_RESERVED_PEERS}. Run export-peer-config.sh after bootstrap." >&2
    exit 1
  fi
fi

exec "${ROOT_DIR}/scripts/prepare-new-node.sh" --type rpc "$@"

