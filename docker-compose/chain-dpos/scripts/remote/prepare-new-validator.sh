#!/usr/bin/env bash
# Server: render envs + generate compose-${NODE_ID}.yml for a new validator.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/new-validator-compose.sh
source "${ROOT_DIR}/scripts/lib/new-validator-compose.sh"

NODE_ID="${NODE_ID:-}"
SKIP_RENDER=false

usage() {
  cat <<'EOF'
Usage: NODE_ID=validator-N ./scripts/remote/prepare-new-validator.sh [options]

Generate envs/<NODE_ID>.env, overrides/<NODE_ID>.override.yml, compose-<NODE_ID>.yml.

Options:
  --skip-render   Skip render-envs.sh (envs already rendered)
  -h, --help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-render) SKIP_RENDER=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

if [ -z "${NODE_ID}" ]; then
  echo "NODE_ID is required (e.g. validator-2 or 2)." >&2
  usage
  exit 1
fi

cd "${ROOT_DIR}"

if [ ! -f envs/deploy.env ]; then
  echo "Missing envs/deploy.env — sync from operator or copy deploy.env.example." >&2
  exit 1
fi

if [ "${SKIP_RENDER}" = false ]; then
  echo "=== Render env files ==="
  ./scripts/render-envs.sh envs/deploy.env
fi

echo "=== Generate compose for ${NODE_ID} ==="
new_validator_prepare_files "${ROOT_DIR}" "${NODE_ID}"

echo ""
echo "Ready: compose-${NODE_ID}.yml"
echo "Start: ./scripts/remote/new-validator-up.sh   (or: make ssh-new-validator-up from operator)"
