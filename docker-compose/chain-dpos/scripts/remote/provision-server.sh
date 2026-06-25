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
  apt-get install -y -qq ca-certificates curl gnupg jq openssl rsync git make
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

configure_docker_logging() {
  local daemon_json="/etc/docker/daemon.json"
  local max_size="${DOCKER_LOG_MAX_SIZE:-10m}"
  local max_file="${DOCKER_LOG_MAX_FILE:-3}"
  local previous=""

  install -m 0755 -d /etc/docker

  if [ -f "${daemon_json}" ]; then
    previous="$(cat "${daemon_json}")"
  fi

  if [ -n "${previous}" ]; then
    echo "${previous}" | jq \
      --arg ms "${max_size}" \
      --arg mf "${max_file}" \
      '.["log-driver"] = "json-file"
       | .["log-opts"] = ((.["log-opts"] // {}) + {"max-size": $ms, "max-file": $mf})' \
      > "${daemon_json}.tmp"
  else
    jq -n \
      --arg ms "${max_size}" \
      --arg mf "${max_file}" \
      '{
        "log-driver": "json-file",
        "log-opts": {
          "max-size": $ms,
          "max-file": $mf
        }
      }' > "${daemon_json}.tmp"
  fi

  mv "${daemon_json}.tmp" "${daemon_json}"
  chmod 0644 "${daemon_json}"

  echo "Docker log rotation: max-size=${max_size}, max-file=${max_file} (${daemon_json})"

  if [ "${previous}" != "$(cat "${daemon_json}")" ]; then
    echo "Restarting Docker to apply daemon.json..."
    systemctl restart docker
  fi
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
  local owner="${DEPLOY_USER:-${SUDO_USER:-}}"

  mkdir -p "${dir}"
  if [ -n "${owner}" ]; then
    chown -R "${owner}:${owner}" "${dir}"
    echo "Deploy root: ${dir} (owner: ${owner})"
  else
    echo "Deploy root: ${dir}" >&2
    echo "Warning: set DEPLOY_USER (e.g. ubuntu) so rsync can write to ${dir}." >&2
  fi
}

usage() {
  cat <<'EOF'
Usage: sudo ./provision-server.sh

Environment (optional):
  BLOCKCHAIN_DOCK_ROOT  Default /opt/blockchain-dock
  DEPLOY_USER           chown deploy dir to this user (e.g. ubuntu)
  DOCKER_LOG_MAX_SIZE   json-file log max size per file (default 10m)
  DOCKER_LOG_MAX_FILE   json-file log file count (default 3)
  OPEN_P2P_PORT=1       Allow P2P port 30300 TCP/UDP via ufw (for cross-server peers)
  P2P_PORT              P2P listen port (default 30300)

Installs: docker, docker compose, node 18+, jq, curl, openssl, rsync, git, make
Configures: /etc/docker/daemon.json log rotation (3 × 10MB per container)
Optional: ufw rules for P2P when OPEN_P2P_PORT=1
EOF
}

main() {
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
  esac

  require_root
  install_packages
  install_docker
  configure_docker_logging
  install_node
  create_deploy_dir

  if [ "${OPEN_P2P_PORT:-}" = "1" ] || [ "${OPEN_P2P_PORT:-}" = "true" ]; then
    _provision_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    _p2p_lib="${_provision_dir}/../lib/open-p2p-firewall.sh"
    if [ ! -f "${_p2p_lib}" ] && [ -n "${PROVISION_LIB_DIR:-}" ]; then
      _p2p_lib="${PROVISION_LIB_DIR}/open-p2p-firewall.sh"
    fi
    if [ ! -f "${_p2p_lib}" ]; then
      echo "Missing open-p2p-firewall.sh (looked in ${_provision_dir}/../lib/)" >&2
      exit 1
    fi
    # shellcheck source=../lib/open-p2p-firewall.sh
    source "${_p2p_lib}"
    open_p2p_firewall
  fi

  echo ""
  echo "Provision complete."
  echo "Next (from operator machine):"
  echo "  1. ./scripts/local/prepare-deploy.sh"
  echo "  2. ./scripts/local/sync-to-server.sh user@this-host"
  echo "  3. ssh user@this-host 'cd /opt/blockchain-dock/blockchain-dockerize/docker-compose/chain-dpos && ./scripts/remote/deploy-validator.sh'"
}

main "$@"
