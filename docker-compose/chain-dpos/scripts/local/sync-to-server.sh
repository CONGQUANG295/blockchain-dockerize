#!/usr/bin/env bash
# Operator machine: rsync deployment bundle to target server (no git clone on server).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCK_ROOT="$(cd "${ROOT_DIR}/../../.." && pwd)"
CONTRACTS_DIR="${DOCK_ROOT}/blockchain-docker-base/resources/dpos-contracts"

REMOTE=""
REMOTE_DIR="${BLOCKCHAIN_DOCK_ROOT:-/opt/blockchain-dock}"
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

Excludes: nodes/*/data, data/* (chain/DApps DB recreated on server).
Includes: genesis, keystore, envs, compose, scripts.
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
      elif [ "${REMOTE_DIR}" = "/opt/blockchain-dock" ] && [[ "$1" != user@* ]]; then
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

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync required on operator machine." >&2
  exit 1
fi

REMOTE_CHAIN="${REMOTE_DIR}/blockchain-dockerize/docker-compose/chain-dpos"
REMOTE_CONTRACTS="${REMOTE_DIR}/blockchain-docker-base/resources/dpos-contracts"

RSYNC_OPTS=(-avz --delete)
EXCLUDES=(
  --exclude 'nodes/validator-1/data/'
  --exclude 'nodes/rpc/data/'
  --exclude 'data/'
  --exclude '.git/'
)

run_rsync() {
  local src="$1"
  local dest="$2"
  if [ "${DRY_RUN}" = true ]; then
    echo "rsync ${RSYNC_OPTS[*]} ${EXCLUDES[*]} ${src} ${dest}"
  else
    rsync "${RSYNC_OPTS[@]}" "${EXCLUDES[@]}" "${src}" "${dest}"
  fi
}

echo "Target: ${REMOTE}:${REMOTE_DIR}"

if [ "${DRY_RUN}" = false ]; then
  ssh "${REMOTE}" "mkdir -p '${REMOTE_CHAIN}' '${REMOTE_CONTRACTS}'"
fi

run_rsync "${CONTRACTS_DIR}/" "${REMOTE}:${REMOTE_CONTRACTS}/"
run_rsync "${ROOT_DIR}/" "${REMOTE}:${REMOTE_CHAIN}/"

if [ "${DRY_RUN}" = false ]; then
  ssh "${REMOTE}" "chmod +x '${REMOTE_CHAIN}/scripts/remote/'*.sh '${REMOTE_CHAIN}/scripts/'*.sh 2>/dev/null || true"
fi

echo ""
echo "Sync complete."
echo "On server:"
echo "  ssh ${REMOTE}"
echo "  cd ${REMOTE_CHAIN}"
echo "  ./scripts/remote/deploy-validator.sh --with-traefik"
echo "  ./scripts/remote/deploy-dapps.sh"
