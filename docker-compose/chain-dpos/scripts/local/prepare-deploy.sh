#!/usr/bin/env bash
# Operator machine: configure deploy.env, render envs, prepare genesis (phase A).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCK_ROOT="$(cd "${ROOT_DIR}/../../.." && pwd)"
CONTRACTS_DIR="${DOCK_ROOT}/blockchain-docker-base/resources/dpos-contracts"

WITH_TRAEFIK=false

usage() {
  cat <<'EOF'
Usage: ./scripts/local/prepare-deploy.sh [options]

Run on operator machine (full blockchain-dock clone). Prepares genesis + env files
before syncing to the target server.

Options:
  --with-traefik   Render Traefik domains into env files (required for DApps + SSL)
  -h, --help       Show this help

Steps:
  1. cp envs/deploy.env.example envs/deploy.env  (if missing) — edit DOCKERHUB_NAMESPACE, chain params, domains
  2. This script: render-envs + prepare-genesis
  3. ./scripts/local/sync-to-server.sh user@host
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --with-traefik) WITH_TRAEFIK=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

cd "${ROOT_DIR}"

if [ ! -d "${CONTRACTS_DIR}" ]; then
  echo "Missing ${CONTRACTS_DIR}" >&2
  echo "Clone full blockchain-dock repo (blockchain-docker-base + blockchain-dockerize)." >&2
  exit 1
fi

if [ ! -f envs/deploy.env ]; then
  cp envs/deploy.env.example envs/deploy.env
  echo "Created envs/deploy.env — edit DOCKERHUB_NAMESPACE, NETWORK_*, domains, then re-run."
  exit 1
fi

set -a
# shellcheck disable=SC1090
source envs/deploy.env
set +a

if [ -z "${DOCKERHUB_NAMESPACE:-}" ] || [ "${DOCKERHUB_NAMESPACE}" = "your-dockerhub-username" ]; then
  echo "Set DOCKERHUB_NAMESPACE in envs/deploy.env to your Docker Hub namespace." >&2
  exit 1
fi

for cmd in node jq openssl; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing ${cmd} on operator machine." >&2
    exit 1
  fi
done

RENDER_ARGS=()
[ "${WITH_TRAEFIK}" = true ] && RENDER_ARGS+=(--with-traefik)

echo "=== Render env files ==="
./scripts/render-envs.sh envs/deploy.env "${RENDER_ARGS[@]}"

echo "=== Prepare genesis (phase A) ==="
./scripts/prepare-genesis.sh

echo ""
echo "Local prepare complete."
echo "  validator: $(cat genesis/validator-1.address)"
echo ""
echo "Next: ./scripts/local/sync-to-server.sh user@your-server"
