#!/usr/bin/env bash
# Stop validator-1 stack and leftover deployer containers (safe before re-deploy).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

FORCE=false

usage() {
  cat <<'EOF'
Usage: ./scripts/stop-validator-nodes.sh [--force]

Stops:
  - compose-validator-1 (openethereum, netstats-api, validator-app)
  - leftover dpos-deployer / deployer-run containers

Does not delete genesis/, nodes/, or chain data volumes on host.

Options:
  --force   docker compose down without prompting
  -h, --help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --force|-f) FORCE=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

DOWN_ARGS=()
[ "${FORCE}" = true ] && DOWN_ARGS+=(--remove-orphans)

# shellcheck source=lib/compose.sh
source "${ROOT_DIR}/scripts/lib/compose.sh"

echo "=== Stopping validator-1 stack ==="
chain_dpos_compose "${ROOT_DIR}" -f compose-validator-1.yml --profile consensus down "${DOWN_ARGS[@]}" || true

echo "=== Removing leftover deployer containers ==="
while IFS= read -r id; do
  [ -n "${id}" ] || continue
  docker rm -f "${id}" >/dev/null 2>&1 || true
done < <(docker ps -aq --filter name=dpos-deployer 2>/dev/null || true)

while IFS= read -r id; do
  [ -n "${id}" ] || continue
  docker rm -f "${id}" >/dev/null 2>&1 || true
done < <(docker ps -aq --filter name=deployer-run 2>/dev/null || true)

echo "Validator nodes stopped. Chain data kept under nodes/validator-1/data/"
echo "Re-deploy: ./scripts/bootstrap-chain.sh --skip-genesis"
echo "Or remote: make dpos ssh-deploy-validator SERVER=user@host REMOTE_DIR=..."
