#!/usr/bin/env bash
# Operator machine: SSH to server and run provision-server.sh (one-time setup).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=ssh-common.sh
source "${SCRIPT_DIR}/ssh-common.sh"

REMOTE=""
DEPLOY_USER=""
REMOTE_DIR="${BLOCKCHAIN_DOCK_ROOT:-/opt/blockchain-dock}"
OPEN_P2P_PORT=""

usage() {
  cat <<'EOF'
Usage: ./scripts/local/provision-remote.sh user@host [options]

One-time server setup via SSH: Docker, Compose, Node 18+, jq, rsync.
Requires SSH key on server (run setup-ssh.sh first).

Options:
  --deploy-user USER   chown /opt/blockchain-dock to USER (default: SSH login user)
  --remote-dir DIR     Default /opt/blockchain-dock
  --open-p2p-port      Open P2P port 30300 TCP/UDP via ufw on server
  -h, --help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --deploy-user) DEPLOY_USER="$2"; shift ;;
    --remote-dir) REMOTE_DIR="$2"; shift ;;
    --open-p2p-port) OPEN_P2P_PORT=1 ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [ -z "${REMOTE}" ]; then
        REMOTE="$1"
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

if [ -z "${DEPLOY_USER}" ]; then
  DEPLOY_USER="${REMOTE%%@*}"
fi

echo "Provisioning ${REMOTE} (deploy root: ${REMOTE_DIR}, owner: ${DEPLOY_USER})..."

require_ssh_key_auth "${REMOTE}"
init_ssh_mux "${REMOTE}"

STAGING="/tmp/blockchain-dock-provision-${USER}-$$"
cleanup() {
  ssh_cmd "${REMOTE}" "rm -rf '${STAGING}'" 2>/dev/null || true
  close_ssh_mux
}
trap cleanup EXIT

ssh_cmd "${REMOTE}" "mkdir -p '${STAGING}/scripts/lib' '${STAGING}/scripts/remote'"
rsync -az "${ROOT_DIR}/scripts/remote/provision-server.sh" "${REMOTE}:${STAGING}/scripts/remote/"
rsync -az "${ROOT_DIR}/scripts/lib/open-p2p-firewall.sh" "${REMOTE}:${STAGING}/scripts/lib/"
ssh_cmd "${REMOTE}" "chmod +x '${STAGING}/scripts/remote/provision-server.sh'"

ssh_cmd -t "${REMOTE}" \
  "sudo BLOCKCHAIN_DOCK_ROOT='${REMOTE_DIR}' DEPLOY_USER='${DEPLOY_USER}' OPEN_P2P_PORT='${OPEN_P2P_PORT}' bash '${STAGING}/scripts/remote/provision-server.sh'"
