#!/usr/bin/env bash
# Operator machine: push peer bundle from local repo to a non-seed server.
# sync-to-server.sh excludes these files to avoid overwriting the seed validator.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ssh-common.sh
source "${SCRIPT_DIR}/ssh-common.sh"

ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GENESIS_DIR="${ROOT_DIR}/genesis"

REMOTE=""
REMOTE_DIR="${REMOTE_DIR:-${BLOCKCHAIN_DOCK_ROOT:-/opt/blockchain-dock}}"
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: ./scripts/local/sync-peer-bundle.sh user@host [remote_dir] [options]

Push peer bundle from local repo to a non-seed server (explorer, new validator):

  genesis/spec.json
  genesis/contract-addresses.json
  genesis/reserved-peers.txt
  genesis/validator-1.enode
  genesis/peers/

sync-to-server.sh excludes these files — run this after make sync on non-seed targets.

Options:
  --dry-run      Print commands without syncing
  -h, --help

Makefile:
  make sync-peer-bundle SERVER=user@host [REMOTE_DIR=...]
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [ -z "${REMOTE}" ]; then
        REMOTE="$1"
      elif [[ "$1" != *@* ]]; then
        REMOTE_DIR="$1"
      else
        echo "Unexpected argument: $1" >&2
        usage
        exit 1
      fi
      ;;
  esac
  shift
done

if [ -z "${REMOTE}" ]; then
  usage
  exit 1
fi

REMOTE_CHAIN="${REMOTE_DIR}/blockchain-dockerize/docker-compose/chain-dpos"
REMOTE_GENESIS="${REMOTE_CHAIN}/genesis"

missing=()
for artifact in spec.json contract-addresses.json reserved-peers.txt validator-1.enode; do
  if [ ! -f "${GENESIS_DIR}/${artifact}" ]; then
    missing+=("genesis/${artifact}")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  echo "Missing local peer bundle:" >&2
  printf '  %s\n' "${missing[@]}" >&2
  echo "Capture from seed first: make pull-peer-config SERVER=user@seed-host" >&2
  exit 1
fi

if [ ! -d "${GENESIS_DIR}/peers" ] || [ -z "$(ls -A "${GENESIS_DIR}/peers" 2>/dev/null || true)" ]; then
  echo "Missing or empty genesis/peers/ — capture from seed first." >&2
  exit 1
fi

run_scp() {
  local src="$1"
  local dest="$2"
  if [ "${DRY_RUN}" = true ]; then
    echo "scp ${src} ${REMOTE}:${dest}"
    return 0
  fi
  scp "${SSH_OPTS[@]}" "${src}" "${REMOTE}:${dest}"
}

run_rsync_push() {
  local src="$1"
  local dest="$2"
  if [ "${DRY_RUN}" = true ]; then
    echo "rsync -avz ${src} ${REMOTE}:${dest}"
    return 0
  fi
  rsync -avz "${src}" "${REMOTE}:${dest}"
}

if [ "${DRY_RUN}" = false ]; then
  require_ssh_key_auth "${REMOTE}"
  init_ssh_mux "${REMOTE}"
  trap close_ssh_mux EXIT
fi

echo "=== Push peer bundle to ${REMOTE}:${REMOTE_GENESIS}/ ==="

if [ "${DRY_RUN}" = false ]; then
  ssh_cmd "${REMOTE}" "mkdir -p '${REMOTE_GENESIS}/peers'"
fi

for artifact in spec.json contract-addresses.json reserved-peers.txt validator-1.enode; do
  run_scp "${GENESIS_DIR}/${artifact}" "${REMOTE_GENESIS}/"
done
run_rsync_push "${GENESIS_DIR}/peers/" "${REMOTE_GENESIS}/peers/"

echo ""
echo "Peer bundle pushed to ${REMOTE}:${REMOTE_GENESIS}/"
[ -f "${GENESIS_DIR}/reserved-peers.txt" ] && \
  echo "  reserved-peers: $(wc -l < "${GENESIS_DIR}/reserved-peers.txt") peer(s)"
