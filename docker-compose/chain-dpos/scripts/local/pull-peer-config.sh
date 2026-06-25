#!/usr/bin/env bash
# Operator machine: pull peer bundle from seed validator server for new node setup.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ssh-common.sh
source "${SCRIPT_DIR}/ssh-common.sh"

ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GENESIS_DIR="${ROOT_DIR}/genesis"
ENVS_DIR="${ROOT_DIR}/envs"

REMOTE=""
REMOTE_DIR="${REMOTE_DIR:-${BLOCKCHAIN_DOCK_ROOT:-/opt/blockchain-dock}}"
REFRESH_ON_SERVER=true
BUNDLE_ONLY=false

usage() {
  cat <<'EOF'
Usage: ./scripts/local/pull-peer-config.sh user@host [remote_dir] [options]

Pull peer bundle from seed validator server to local (before RPC / new validator):

  genesis/spec.json
  genesis/contract-addresses.json
  genesis/reserved-peers.txt
  genesis/validator-1.enode
  genesis/peers/*.enode

On server, runs export-peer-config.sh first (refresh enode + reserved-peers).

Options:
  --skip-refresh     Do not run export-peer-config on server; pull existing files
  --bundle-only      Skip running prepare-new-node after pull
  -h, --help

Example:
  make pull-peer-config SERVER=root@91.229.245.75 REMOTE_DIR=/opt/blockchain-gtbs
  make prepare-new-node SERVER=... TYPE=rpc
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-refresh) REFRESH_ON_SERVER=false ;;
    --bundle-only) BUNDLE_ONLY=true ;;
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

DRY_RUN="${DRY_RUN:-false}"

if [ -f "${ENVS_DIR}/deploy.env" ]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENVS_DIR}/deploy.env"
  set +a
fi

REMOTE_CHAIN="${REMOTE_DIR}/blockchain-dockerize/docker-compose/chain-dpos"
REMOTE_GENESIS="${REMOTE_CHAIN}/genesis"

ssh_host_from_target() {
  local target="${1#*@}"
  echo "${target%%:*}"
}

resolve_public_ip() {
  if [ -n "${P2P_PUBLIC_IP:-}" ]; then
    echo "${P2P_PUBLIC_IP}"
    return 0
  fi
  local host
  host="$(ssh_host_from_target "${REMOTE}")"
  if [[ "${host}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "${host}"
    return 0
  fi
  return 1
}

run_ssh() {
  if [ "${DRY_RUN}" = true ]; then
    echo "ssh ${REMOTE} $*"
    return 0
  fi
  ssh_cmd "${REMOTE}" "$@"
}

run_rsync_pull() {
  local remote_path="$1"
  local local_path="$2"
  if [ "${DRY_RUN}" = true ]; then
    echo "rsync -avz ${REMOTE}:${remote_path} ${local_path}"
    return 0
  fi
  if ! ssh_cmd "${REMOTE}" "test -e '${remote_path}'"; then
    echo "Skip missing remote: ${remote_path}" >&2
    return 0
  fi
  rsync -avz "${REMOTE}:${remote_path}" "${local_path}"
}

mkdir -p "${GENESIS_DIR}/peers"

if [ "${DRY_RUN}" = false ]; then
  require_ssh_key_auth "${REMOTE}"
  init_ssh_mux "${REMOTE}"
  trap close_ssh_mux EXIT
fi

if [ "${DRY_RUN}" = false ]; then
  if ! ssh_cmd "${REMOTE}" "test -d '${REMOTE_CHAIN}'"; then
    echo "Remote path not found: ${REMOTE_CHAIN}" >&2
    echo "Sync first: make sync SERVER=${REMOTE} REMOTE_DIR=${REMOTE_DIR}" >&2
    exit 1
  fi
fi

PUBLIC_IP="$(resolve_public_ip || true)"
P2P_PORT="${P2P_PORT:-30300}"

if [ "${REFRESH_ON_SERVER}" = true ]; then
  echo "=== Export peer config on server ==="
  refresh_env="P2P_PORT=${P2P_PORT}"
  if [ -n "${PUBLIC_IP}" ]; then
    refresh_env="${refresh_env} P2P_PUBLIC_IP=${PUBLIC_IP} OPEN_P2P_PORT=1"
  fi
  run_ssh "cd '${REMOTE_CHAIN}' && ${refresh_env} ./scripts/export-peer-config.sh"
fi

echo "=== Pull peer bundle to local ==="
for artifact in spec.json contract-addresses.json reserved-peers.txt validator-1.enode; do
  run_rsync_pull "${REMOTE_GENESIS}/${artifact}" "${GENESIS_DIR}/"
done
run_rsync_pull "${REMOTE_GENESIS}/peers/" "${GENESIS_DIR}/peers/"

echo ""
echo "Local peer bundle: ${GENESIS_DIR}/"
[ -f "${GENESIS_DIR}/reserved-peers.txt" ] && echo "  reserved-peers: $(wc -l < "${GENESIS_DIR}/reserved-peers.txt") peer(s)"
[ -f "${GENESIS_DIR}/spec.json" ] && echo "  spec.json: present"
[ -f "${GENESIS_DIR}/contract-addresses.json" ] && echo "  contract-addresses.json: present"
echo ""
echo "Prepare a new node:"
echo "  ./scripts/prepare-new-node.sh --type rpc"
echo "  ./scripts/prepare-new-node.sh --type validator --node-id validator-N"
