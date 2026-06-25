#!/usr/bin/env bash
# Operator machine: prepare / up / down / logs for new validator on remote server.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ssh-common.sh
source "${SCRIPT_DIR}/ssh-common.sh"

REMOTE=""
REMOTE_DIR="${REMOTE_DIR:-${BLOCKCHAIN_DOCK_ROOT:-/opt/blockchain-dock}}"
NODE_ID=""
ACTION=""
EXTRA_ARGS=()

usage() {
  cat <<'EOF'
Usage: ./scripts/local/ssh-new-validator.sh user@host ACTION [options]

Actions:
  prepare     Render env + generate compose-<NODE_ID>.yml on server
  up          prepare (if needed) + docker compose up -d
  down        docker compose down
  logs        docker compose logs -f

Required env/flags:
  NODE_ID=validator-N   (required for all actions)

Options:
  --remote-dir DIR      Default /opt/blockchain-dock
  --skip-render         prepare: skip render-envs.sh
  --skip-pull           up: skip compose pull
  -h, --help

Makefile:
  make ssh-new-validator-prepare SERVER=user@host NODE_ID=2 REMOTE_DIR=...
  make ssh-new-validator-up SERVER=user@host NODE_ID=2
  make ssh-new-validator-down SERVER=user@host NODE_ID=2
  make ssh-new-validator-logs SERVER=user@host NODE_ID=2
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    prepare|up|down|logs) ACTION="$1" ;;
    --remote-dir) REMOTE_DIR="${2:?}"; shift ;;
    --node-id) NODE_ID="${2:?}"; shift ;;
    --skip-render) EXTRA_ARGS+=(--skip-render) ;;
    --skip-pull) EXTRA_ARGS+=(--skip-pull) ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [ -z "${REMOTE}" ]; then
        REMOTE="$1"
      elif [[ "$1" == /* ]]; then
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

NODE_ID="${NODE_ID:-${NEW_VALIDATOR_NODE_ID:-}}"

if [ -z "${REMOTE}" ] || [ -z "${ACTION}" ]; then
  usage
  exit 1
fi

if [ -z "${NODE_ID}" ]; then
  echo "NODE_ID is required (e.g. NODE_ID=2 or NODE_ID=validator-2)." >&2
  exit 1
fi

REMOTE_CHAIN="${REMOTE_DIR}/blockchain-dockerize/docker-compose/chain-dpos"

require_ssh_key_auth "${REMOTE}"
init_ssh_mux "${REMOTE}"
trap close_ssh_mux EXIT

if ! ssh_cmd "${REMOTE}" "test -d '${REMOTE_CHAIN}'"; then
  echo "Remote path not found: ${REMOTE_CHAIN}" >&2
  echo "Sync first: make sync-new-validator SERVER=${REMOTE} NODE_ID=${NODE_ID} REMOTE_DIR=${REMOTE_DIR}" >&2
  exit 1
fi

remote_env="NODE_ID='${NODE_ID}' REMOTE_DIR='${REMOTE_DIR}'"

case "${ACTION}" in
  prepare)
  ssh_cmd "${REMOTE}" "cd '${REMOTE_CHAIN}' && ${remote_env} ./scripts/remote/prepare-new-validator.sh ${EXTRA_ARGS[*]:-}"
    ;;
  up)
    ssh_cmd -t "${REMOTE}" "cd '${REMOTE_CHAIN}' && ${remote_env} ./scripts/remote/new-validator-up.sh ${EXTRA_ARGS[*]:-}"
    ;;
  down)
    ssh_cmd "${REMOTE}" "cd '${REMOTE_CHAIN}' && ${remote_env} ./scripts/remote/new-validator-down.sh"
    ;;
  logs)
    ssh_cmd -t "${REMOTE}" "cd '${REMOTE_CHAIN}' && source scripts/lib/compose.sh && chain_dpos_compose '${REMOTE_CHAIN}' -f compose-${NODE_ID}.yml logs -f --tail=100"
    ;;
esac
