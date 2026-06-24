#!/usr/bin/env bash
# One-time migration from pre-refactor layout to nodes/ + chain-dpos/data/.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/paths.sh
source "${ROOT_DIR}/scripts/lib/paths.sh"
chain_dpos_paths "${ROOT_DIR}"

LEGACY_KEYSTORE="${PATH_GENESIS}/validator-1"
LEGACY_CONFIG="${ROOT_DIR}/config"
LEGACY_DATA="${ROOT_DIR}/../data"

migrate_dir() {
  local src="$1" dest="$2"
  if [ -d "${src}" ] && [ "$(ls -A "${src}" 2>/dev/null || true)" ] && [ ! -d "${dest}" ] || [ -z "$(ls -A "${dest}" 2>/dev/null || true)" ]; then
    mkdir -p "$(dirname "${dest}")"
    if [ -d "${dest}" ] && [ -z "$(ls -A "${dest}" 2>/dev/null || true)" ]; then
      rmdir "${dest}" 2>/dev/null || true
    fi
    if [ ! -e "${dest}" ]; then
      echo "mv ${src} -> ${dest}"
      mv "${src}" "${dest}"
    fi
  fi
}

migrate_file() {
  local src="$1" dest="$2"
  if [ -f "${src}" ] && [ ! -f "${dest}" ]; then
    mkdir -p "$(dirname "${dest}")"
    echo "mv ${src} -> ${dest}"
    mv "${src}" "${dest}"
  fi
}

chain_dpos_ensure_node_dirs

if [ -d "${LEGACY_KEYSTORE}/keystore" ]; then
  migrate_dir "${LEGACY_KEYSTORE}/keystore" "${PATH_VALIDATOR_KEYSTORE}"
  migrate_file "${LEGACY_KEYSTORE}/node.pwd" "${PATH_VALIDATOR_PASSWORD}"
fi

migrate_file "${LEGACY_CONFIG}/validator-1.toml" "${PATH_VALIDATOR_CONFIG}"
migrate_file "${LEGACY_CONFIG}/rpc.toml" "${PATH_RPC_CONFIG}"
migrate_file "${LEGACY_CONFIG}/reserved-peers.txt" "${PATH_RESERVED_PEERS}"

if [ -d "${LEGACY_DATA}" ]; then
  for sub in dpos-blockscout-db dpos-stats-db traefik proxy certbot docs; do
    if [ -e "${LEGACY_DATA}/${sub}" ] && [ ! -e "${PATH_DATA}/${sub}" ]; then
      echo "mv ${LEGACY_DATA}/${sub} -> ${PATH_DATA}/${sub}"
      mv "${LEGACY_DATA}/${sub}" "${PATH_DATA}/${sub}"
    fi
  done
fi

echo ""
echo "Migration complete. If validator/RPC used Docker named volumes, export chain data manually:"
echo "  docker volume inspect dpos-validator-1_openethereum_db"
echo "  docker volume inspect dpos-dapps-traefik-v11_openethereum_rpc_db"
echo "Then bind-export into nodes/validator-1/data and nodes/rpc/data before restart."
