#!/usr/bin/env bash
# Operator machine: SSH to server and run provision-server.sh (one-time setup).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROVISION="${ROOT_DIR}/scripts/remote/provision-server.sh"

REMOTE=""
DEPLOY_USER=""
REMOTE_DIR="${BLOCKCHAIN_DOCK_ROOT:-/opt/blockchain-dock}"

usage() {
  cat <<'EOF'
Usage: ./scripts/local/provision-remote.sh user@host [options]

One-time server setup via SSH: Docker, Compose, Node 18+, jq, rsync.

Options:
  --deploy-user USER   chown /opt/blockchain-dock to USER (default: SSH login user)
  --remote-dir DIR     Default /opt/blockchain-dock
  -h, --help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --deploy-user) DEPLOY_USER="$2"; shift ;;
    --remote-dir) REMOTE_DIR="$2"; shift ;;
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

ssh -t "${REMOTE}" "sudo BLOCKCHAIN_DOCK_ROOT='${REMOTE_DIR}' DEPLOY_USER='${DEPLOY_USER}' bash -s" < "${PROVISION}"
