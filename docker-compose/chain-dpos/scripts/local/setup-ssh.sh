#!/usr/bin/env bash
# Operator machine: install local SSH public key on remote server (one-time).
set -euo pipefail

REMOTE=""

usage() {
  cat <<'EOF'
Usage: ./scripts/local/setup-ssh.sh user@host

Copy your SSH public key to the server (ssh-copy-id). After this, provision/sync/deploy
run without repeated password prompts.

Prerequisites:
  - ssh-keygen -t ed25519   (if ~/.ssh/id_ed25519.pub does not exist)
  - Server user can login with password once (for ssh-copy-id)

Makefile:
  make dpos setup-ssh SERVER=ubuntu@your-server
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

if ! command -v ssh-copy-id >/dev/null 2>&1; then
  echo "ssh-copy-id not found. Install openssh-client." >&2
  exit 1
fi

KEY_FILE="${SSH_PUBLIC_KEY:-}"
if [ -z "${KEY_FILE}" ]; then
  for candidate in "${HOME}/.ssh/id_ed25519.pub" "${HOME}/.ssh/id_rsa.pub"; do
    if [ -f "${candidate}" ]; then
      KEY_FILE="${candidate}"
      break
    fi
  done
fi

if [ -z "${KEY_FILE}" ] || [ ! -f "${KEY_FILE}" ]; then
  echo "No SSH public key found. Generate one:" >&2
  echo "  ssh-keygen -t ed25519 -C \"\$(whoami)@\$(hostname)\"" >&2
  exit 1
fi

echo "Installing ${KEY_FILE} on ${REMOTE}..."
ssh-copy-id -i "${KEY_FILE}" "${REMOTE}"

echo ""
echo "Verifying key-based login..."
ssh -o BatchMode=yes "${REMOTE}" "echo 'SSH key OK — user='\$(whoami)' host='\$(hostname)"

echo ""
echo "Setup complete. Remote deploy without password:"
echo "  make dpos provision-remote SERVER=${REMOTE} [REMOTE_DIR=...]"
echo "  make dpos sync SERVER=${REMOTE} [REMOTE_DIR=...]"
echo "  make dpos ssh-deploy-validator SERVER=${REMOTE} [REMOTE_DIR=...]"
