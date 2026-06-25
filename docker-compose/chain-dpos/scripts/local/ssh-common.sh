# Shared SSH helpers for operator scripts (source, do not execute).
# Usage:
#   source "${SCRIPT_DIR}/ssh-common.sh"
#   require_ssh_key_auth "${REMOTE}"
#   init_ssh_mux "${REMOTE}"
#   ssh_cmd "${REMOTE}" "echo ok"
#   close_ssh_mux

REMOTE_SSH_TARGET=""
SSH_CONTROL_PATH=""
SSH_OPTS=()

init_ssh_mux() {
  local remote="$1"
  REMOTE_SSH_TARGET="${remote}"
  SSH_CONTROL_PATH="${TMPDIR:-/tmp}/blockchain-dock-ssh-${USER}-$$"
  SSH_OPTS=(
    -o ControlMaster=auto
    -o "ControlPath=${SSH_CONTROL_PATH}"
    -o ControlPersist=300
  )
  export RSYNC_RSH="ssh -o ControlMaster=auto -o ControlPath=${SSH_CONTROL_PATH} -o ControlPersist=300"
}

ssh_cmd() {
  ssh "${SSH_OPTS[@]}" "$@"
}

close_ssh_mux() {
  if [ -z "${REMOTE_SSH_TARGET}" ] || [ -z "${SSH_CONTROL_PATH}" ]; then
    return 0
  fi
  ssh -O exit -o "ControlPath=${SSH_CONTROL_PATH}" "${REMOTE_SSH_TARGET}" 2>/dev/null || true
}

require_ssh_key_auth() {
  local remote="$1"
  if ssh -o BatchMode=yes -o ConnectTimeout=15 "${remote}" "echo ok" >/dev/null 2>&1; then
    return 0
  fi

  cat >&2 <<EOF
SSH key authentication required for ${remote}.

One-time setup (from operator machine):
  make dpos setup-ssh SERVER=${remote}
  # or: ssh-copy-id ${remote}

Then retry your command.
EOF
  exit 1
}
