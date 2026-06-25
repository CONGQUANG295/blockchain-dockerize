#!/usr/bin/env bash
# Server-side: open P2P port for cross-server validator peering (ufw).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/open-p2p-firewall.sh
source "${ROOT_DIR}/scripts/lib/open-p2p-firewall.sh"

usage() {
  cat <<'EOF'
Usage: sudo OPEN_P2P_PORT=1 ./scripts/remote/open-p2p-port.sh

Opens P2P port (default 30300 TCP/UDP) via ufw for validator peering across hosts.

Environment:
  OPEN_P2P_PORT=1   Required — enables firewall configuration
  P2P_PORT          Default 30300
  SSH_PORT          SSH port to allow first (default 22, auto-detect from sshd_config)

Ensures SSH (port 22 or SSH_PORT) is allowed before opening P2P. Does not run ufw enable.
Also configure cloud security group inbound for the same port if applicable.
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

if [ "$(id -u)" -ne 0 ]; then
  echo "Re-run with sudo: sudo OPEN_P2P_PORT=1 $0" >&2
  exit 1
fi

# Load deploy.env when run from chain-dpos root (optional overrides).
if [ -f "${ROOT_DIR}/envs/deploy.env" ]; then
  set -a
  # shellcheck disable=SC1090
  source "${ROOT_DIR}/envs/deploy.env"
  set +a
fi

open_p2p_firewall
