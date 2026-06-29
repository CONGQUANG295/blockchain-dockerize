#!/usr/bin/env bash
# Operator machine: run a command in chain-dpos on remote server via SSH key.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ssh-common.sh
source "${SCRIPT_DIR}/ssh-common.sh"

REMOTE=""
REMOTE_DIR="${REMOTE_DIR:-${BLOCKCHAIN_DOCK_ROOT:-/opt/blockchain-dock}}"
declare -a REMOTE_CMD=()

usage() {
  cat <<'EOF'
Usage: ./scripts/local/ssh-run-remote.sh user@host [remote_dir] command...

Run command in REMOTE_DIR/.../chain-dpos on server. Requires SSH key (setup-ssh.sh).

Example:
  ./scripts/local/ssh-run-remote.sh ubuntu@host /opt/blockchain-gtbs \
    ./scripts/remote/deploy-validator.sh
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      if [ ${#REMOTE_CMD[@]} -eq 0 ]; then
        usage
        exit 0
      fi
      REMOTE_CMD+=("$1")
      ;;
    --)
      shift
      REMOTE_CMD+=("$@")
      break
      ;;
    -*)
      # Flags after remote command start belong to the remote script (e.g. --force, --with-traefik).
      if [ ${#REMOTE_CMD[@]} -eq 0 ]; then
        echo "Unknown option: $1" >&2
        usage
        exit 1
      fi
      REMOTE_CMD+=("$1")
      ;;
    *)
      if [ -z "${REMOTE}" ]; then
        REMOTE="$1"
      elif [ ${#REMOTE_CMD[@]} -eq 0 ] && [[ "$1" == /* ]]; then
        REMOTE_DIR="$1"
      else
        REMOTE_CMD+=("$1")
      fi
      ;;
  esac
  shift
done

if [ -z "${REMOTE}" ] || [ ${#REMOTE_CMD[@]} -eq 0 ]; then
  usage
  exit 1
fi

REMOTE_CHAIN="${REMOTE_DIR}/blockchain-dockerize/docker-compose/chain-dpos"

require_ssh_key_auth "${REMOTE}"
init_ssh_mux "${REMOTE}"
trap close_ssh_mux EXIT

if ! ssh_cmd "${REMOTE}" "test -d '${REMOTE_CHAIN}'"; then
  echo "Remote path not found: ${REMOTE_CHAIN}" >&2
  echo "Sync first: make dpos sync SERVER=${REMOTE} REMOTE_DIR=${REMOTE_DIR}" >&2
  exit 1
fi

printf -v REMOTE_SHELL_CMD '%q ' "${REMOTE_CMD[@]}"
ssh_cmd "${REMOTE}" "cd '${REMOTE_CHAIN}' && ${REMOTE_SHELL_CMD}"
