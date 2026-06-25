#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

CHAIN_ONLY=false
DAPPS_ONLY=false
WITH_TRAEFIK=false
SKIP_HEALTH=false

while [ $# -gt 0 ]; do
  case "$1" in
    --chain-only) CHAIN_ONLY=true ;;
    --dapps-only) DAPPS_ONLY=true ;;
    --with-traefik|--with-dapps) WITH_TRAEFIK=true ;;
    --skip-health) SKIP_HEALTH=true ;;
    -h|--help)
      echo "Usage: $0 [--chain-only|--dapps-only] [--with-traefik] [--skip-health]"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

RENDER_ARGS=()
[ "${WITH_TRAEFIK}" = true ] && RENDER_ARGS+=(--with-traefik)

if [ "${DAPPS_ONLY}" = false ]; then
  echo "=== Render env + bootstrap chain ==="
  ./scripts/render-envs.sh envs/deploy.env "${RENDER_ARGS[@]}"
  ./scripts/bootstrap-chain.sh
  ./scripts/export-validator-app-env.sh
  set -a
  # shellcheck disable=SC1090
  source envs/validator-app.env
  set +a
  # shellcheck source=lib/compose.sh
  source "${ROOT_DIR}/scripts/lib/compose.sh"
  chain_dpos_compose "${ROOT_DIR}" -f compose-validator-1.yml --profile consensus pull
  chain_dpos_compose "${ROOT_DIR}" -f compose-validator-1.yml --profile consensus up -d validator-app
fi

if [ "${CHAIN_ONLY}" = true ]; then
  echo "Chain-only complete"
  exit 0
fi

echo "=== Prepare RPC + DApps ==="
./scripts/prepare-rpc-node.sh
WITH_TRAEFIK_PREPARE=$([ "${WITH_TRAEFIK}" = true ] && echo true || echo false) \
  ./scripts/prepare-envs-dapps.sh

set -a
# shellcheck disable=SC1090
source envs/dpos.chain.env
set +a

COMPOSE_ARGS=(-f compose-dapps-traefik-v11.yml)
if [ "${NETWORK_TYPE}" = testnet ]; then
  COMPOSE_ARGS+=(--profile faucet)
else
  echo "Mainnet: skipping faucet profile"
fi

docker compose "${COMPOSE_ARGS[@]}" pull
docker compose "${COMPOSE_ARGS[@]}" up -d

if [ "${SKIP_HEALTH}" = false ]; then
  ./scripts/health-check.sh
fi

echo "Deploy complete"
