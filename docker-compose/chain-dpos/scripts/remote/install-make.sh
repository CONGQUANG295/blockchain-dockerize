#!/usr/bin/env bash
# Install GNU make on Ubuntu/Debian (for running chain-dpos Makefile on server).
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Re-run with sudo: sudo $0" >&2
    exit 1
  fi
}

usage() {
  cat <<'EOF'
Usage: sudo ./scripts/remote/install-make.sh

Installs GNU make via apt (Ubuntu/Debian).
EOF
}

install_make() {
  if command -v make >/dev/null 2>&1; then
    echo "make already installed: $(make --version | head -1)"
    return 0
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    echo "Only apt-based systems are supported (Ubuntu/Debian)." >&2
    exit 1
  fi

  apt-get update -qq
  apt-get install -y -qq make
  echo "Installed: $(make --version | head -1)"
}

main() {
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
  esac

  require_root
  install_make

  echo ""
  echo "On server, run Makefile from chain-dpos:"
  echo "  cd \${REMOTE_DIR}/blockchain-dockerize/docker-compose/chain-dpos"
  echo "  make deploy-remote-validator"
  echo "  make stop-validator-nodes"
}

main "$@"
