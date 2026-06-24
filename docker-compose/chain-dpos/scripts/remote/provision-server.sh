#!/usr/bin/env bash
# Install Docker, Compose v2, and host tools required by chain-dpos on Ubuntu/Debian.
# Run on the target server (or via: ssh user@host 'bash -s' < provision-server.sh)
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Re-run with sudo: sudo $0" >&2
    exit 1
  fi
}

install_packages() {
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl gnupg jq openssl rsync git
}

install_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    echo "Docker + Compose plugin already installed"
    docker --version
    docker compose version
    return 0
  fi

  install -m 0755 -d /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  local codename
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    codename="${VERSION_CODENAME:-}"
  fi
  if [ -z "${codename}" ]; then
    echo "Unsupported OS: cannot detect VERSION_CODENAME" >&2
    exit 1
  fi

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    ${codename} stable" > /etc/apt/sources.list.d/docker.list

  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
}

install_node() {
  if command -v node >/dev/null 2>&1; then
    local major
    major="$(node -p 'process.versions.node.split(".")[0]')"
    if [ "${major}" -ge 18 ]; then
      echo "Node.js $(node -v) already installed"
      return 0
    fi
  fi

  curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
  apt-get install -y -qq nodejs
  echo "Node.js $(node -v)"
}

create_deploy_dir() {
  local dir="${BLOCKCHAIN_DOCK_ROOT:-/opt/blockchain-dock}"
  mkdir -p "${dir}"
  if [ -n "${DEPLOY_USER:-}" ]; then
    chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "${dir}"
  fi
  echo "Deploy root: ${dir}"
}

usage() {
  cat <<'EOF'
Usage: sudo ./provision-server.sh

Environment (optional):
  BLOCKCHAIN_DOCK_ROOT  Default /opt/blockchain-dock
  DEPLOY_USER           chown deploy dir to this user (e.g. ubuntu)

Installs: docker, docker compose, node 18+, jq, curl, openssl, rsync, git
EOF
}

main() {
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
  esac

  require_root
  install_packages
  install_docker
  install_node
  create_deploy_dir

  echo ""
  echo "Provision complete."
  echo "Next (from operator machine):"
  echo "  1. ./scripts/local/prepare-deploy.sh"
  echo "  2. ./scripts/local/sync-to-server.sh user@this-host"
  echo "  3. ssh user@this-host 'cd /opt/blockchain-dock/blockchain-dockerize/docker-compose/chain-dpos && ./scripts/remote/deploy-validator.sh'"
}

main "$@"
