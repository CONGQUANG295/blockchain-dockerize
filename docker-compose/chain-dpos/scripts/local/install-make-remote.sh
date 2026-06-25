#!/usr/bin/env bash
# Operator machine: install GNU make on remote server via SSH.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INSTALL_MAKE="${ROOT_DIR}/scripts/remote/install-make.sh"
# shellcheck source=ssh-common.sh
source "${SCRIPT_DIR}/ssh-common.sh"

REMOTE=""

usage() {
  cat <<'EOF'
Usage: ./scripts/local/install-make-remote.sh user@host

Install GNU make on the target server (Ubuntu/Debian, requires sudo).
Requires SSH key (run setup-ssh.sh first).

Example:
  make ssh-install-make SERVER=ubuntu@your-server
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
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

echo "Installing make on ${REMOTE}..."

require_ssh_key_auth "${REMOTE}"
init_ssh_mux "${REMOTE}"
trap close_ssh_mux EXIT

ssh_cmd -t "${REMOTE}" "sudo bash -s" < "${INSTALL_MAKE}"
