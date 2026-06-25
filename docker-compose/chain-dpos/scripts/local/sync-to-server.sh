#!/usr/bin/env bash
# Operator machine: rsync deployment bundle to target server (no git clone on server).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ssh-common.sh
source "${SCRIPT_DIR}/ssh-common.sh"

ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_DIR="$(cd "${ROOT_DIR}/.." && pwd)"
DOCK_ROOT="$(cd "${ROOT_DIR}/../../.." && pwd)"
CONTRACTS_DIR="${DOCK_ROOT}/blockchain-docker-base/resources/dpos-contracts"
SERVICES_DIR="${COMPOSE_DIR}/services"
COMPOSE_ENVS_DIR="${COMPOSE_DIR}/envs"

REMOTE=""
REMOTE_DIR="${REMOTE_DIR:-${BLOCKCHAIN_DOCK_ROOT:-/opt/blockchain-dock}}"
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: ./scripts/local/sync-to-server.sh user@host [remote_dir] [options]

Sync chain-dpos bundle + dpos-contracts to server. Operator machine must have
run prepare-deploy.sh first.

Arguments:
  user@host      SSH target
  remote_dir     Default /opt/blockchain-dock

Options:
  --dry-run      Print rsync command without syncing
  -h, --help     Show this help

Excludes: nodes/*/data, data/* (chain); node_modules, cache, artifacts (contracts).
Includes: genesis, keystore, envs, compose, scripts, dpos-contracts scripts/config,
          docker-compose/services, docker-compose/envs (shared compose env paths).
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [ -z "${REMOTE}" ]; then
        REMOTE="$1"
      elif [[ "$1" != *@* ]]; then
        REMOTE_DIR="$1"
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

if [ ! -f "${ROOT_DIR}/genesis/validator-1.address" ]; then
  echo "Missing genesis — run ./scripts/local/prepare-deploy.sh first." >&2
  exit 1
fi

if [ ! -d "${CONTRACTS_DIR}" ]; then
  echo "Missing ${CONTRACTS_DIR}" >&2
  exit 1
fi

if [ ! -d "${SERVICES_DIR}" ]; then
  echo "Missing ${SERVICES_DIR}" >&2
  exit 1
fi

if [ ! -d "${COMPOSE_ENVS_DIR}" ]; then
  echo "Missing ${COMPOSE_ENVS_DIR}" >&2
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync required on operator machine." >&2
  exit 1
fi

REMOTE_CHAIN="${REMOTE_DIR}/blockchain-dockerize/docker-compose/chain-dpos"
REMOTE_SERVICES="${REMOTE_DIR}/blockchain-dockerize/docker-compose/services"
REMOTE_COMPOSE_ENVS="${REMOTE_DIR}/blockchain-dockerize/docker-compose/envs"
REMOTE_CONTRACTS="${REMOTE_DIR}/blockchain-docker-base/resources/dpos-contracts"
DEPLOY_USER="${REMOTE%%@*}"

if [ "${DRY_RUN}" = false ]; then
  require_ssh_key_auth "${REMOTE}"
  init_ssh_mux "${REMOTE}"
  trap close_ssh_mux EXIT
fi

RSYNC_OPTS=(-avz --delete)
CHAIN_EXCLUDES=(
  --exclude 'nodes/validator-1/data/'
  --exclude 'nodes/rpc/data/'
  --exclude 'data/'
  --exclude 'genesis/contract-addresses.json'
  --exclude 'genesis/reserved-peers.txt'
  --exclude 'genesis/validator-1.enode'
  --exclude 'genesis/peers/'
  --exclude '.git/'
)

CONTRACTS_EXCLUDES=(
  --exclude 'node_modules/'
  --exclude 'cache/'
  --exclude 'artifacts/'
  --exclude 'coverage/'
  --exclude 'test/'
  --exclude '.git/'
)

run_rsync() {
  local src="$1"
  local dest="$2"
  shift 2
  local -a extra_excludes=("$@")
  if [ "${DRY_RUN}" = true ]; then
    echo "rsync ${RSYNC_OPTS[*]} ${extra_excludes[*]} ${src} ${dest}"
  else
    rsync "${RSYNC_OPTS[@]}" "${extra_excludes[@]}" "${src}" "${dest}"
  fi
}

echo "Target: ${REMOTE}:${REMOTE_DIR} (owner: ${DEPLOY_USER})"

ensure_remote_dirs() {
  if [ "${DRY_RUN}" = true ]; then
    echo "ssh ${REMOTE} prepare dirs + cleanup stale node_modules"
    return 0
  fi

  echo "Preparing ${REMOTE_DIR} on ${REMOTE} (owner: ${DEPLOY_USER})..."
  local prep_script
  prep_script="$(cat <<EOF
set -e
if sudo mkdir -p '${REMOTE_CHAIN}' '${REMOTE_SERVICES}' '${REMOTE_COMPOSE_ENVS}' '${REMOTE_CONTRACTS}' && \
   sudo chown -R '${DEPLOY_USER}:${DEPLOY_USER}' '${REMOTE_DIR}'; then
  :
elif mkdir -p '${REMOTE_CHAIN}' '${REMOTE_SERVICES}' '${REMOTE_COMPOSE_ENVS}' '${REMOTE_CONTRACTS}' && test -w '${REMOTE_DIR}'; then
  :
else
  echo "Cannot prepare ${REMOTE_DIR}" >&2
  exit 1
fi
rm -rf '${REMOTE_CONTRACTS}/node_modules' '${REMOTE_CONTRACTS}/cache' 2>/dev/null || true
EOF
)"
  if ! ssh_cmd "${REMOTE}" "${prep_script}"; then
    echo "Cannot prepare ${REMOTE_DIR} on ${REMOTE}." >&2
    echo "Fix on server: sudo chown -R ${DEPLOY_USER}:${DEPLOY_USER} ${REMOTE_DIR}" >&2
    exit 1
  fi
}

ensure_remote_dirs

run_rsync "${CONTRACTS_DIR}/" "${REMOTE}:${REMOTE_CONTRACTS}/" "${CONTRACTS_EXCLUDES[@]}"
run_rsync "${SERVICES_DIR}/" "${REMOTE}:${REMOTE_SERVICES}/" --exclude '.git/'
run_rsync "${COMPOSE_ENVS_DIR}/" "${REMOTE}:${REMOTE_COMPOSE_ENVS}/" --exclude '.git/'
run_rsync "${ROOT_DIR}/" "${REMOTE}:${REMOTE_CHAIN}/" "${CHAIN_EXCLUDES[@]}"

if [ "${DRY_RUN}" = false ]; then
  ssh_cmd "${REMOTE}" "chmod +x '${REMOTE_CHAIN}/scripts/remote/'*.sh '${REMOTE_CHAIN}/scripts/'*.sh 2>/dev/null || true"
fi

echo ""
echo "Sync complete."
echo "On server:"
echo "  ssh ${REMOTE}"
echo "  cd ${REMOTE_CHAIN}"
echo "  ./scripts/remote/deploy-validator.sh --with-traefik"
echo "  ./scripts/remote/deploy-dapps.sh"
