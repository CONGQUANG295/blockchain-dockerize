#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVS_DIR="${ROOT_DIR}/envs"

if [ -f "${ENVS_DIR}/deploy.env" ]; then
  RENDER_ARGS=()
  [ "${WITH_TRAEFIK_PREPARE:-false}" = true ] && RENDER_ARGS+=(--with-traefik)
  "${ROOT_DIR}/scripts/render-envs.sh" "${ENVS_DIR}/deploy.env" "${RENDER_ARGS[@]}"
elif [ ! -f "${ENVS_DIR}/dpos.chain.env" ]; then
  for f in db.env blockscout-backend.env blockscout-frontend.env blockscout-stats.env \
    blockscout-visualizer.env eth-faucet.env netstats-dashboard.env netstats-api.env docs.env traefik.env; do
    if [ ! -f "${ENVS_DIR}/${f}" ]; then
      cp "${ENVS_DIR}/${f}.example" "${ENVS_DIR}/${f}" 2>/dev/null || true
    fi
  done
fi

"${ROOT_DIR}/scripts/traefik/prepare-envs-traefik.sh"
"${ROOT_DIR}/scripts/traefik/generate-blockscout-v11.sh"

if [ ! -f "${ENVS_DIR}/dpos.chain.env" ]; then
  cp "${ENVS_DIR}/dpos.chain.env.example" "${ENVS_DIR}/dpos.chain.env"
fi

set -a
# shellcheck disable=SC1090
source "${ENVS_DIR}/dpos.chain.env"
set +a

CHAIN_ID_DEC=$((16#${NETWORK_ID#0x}))
if grep -q '^CHAIN_ID=' "${ENVS_DIR}/blockscout-backend.env" 2>/dev/null; then
  sed -i "s/^CHAIN_ID=.*/CHAIN_ID=${CHAIN_ID_DEC}/" "${ENVS_DIR}/blockscout-backend.env"
fi

if [ "${NETWORK_TYPE}" = testnet ]; then
  "${ROOT_DIR}/scripts/gen-faucet-wallet.sh"
else
  echo "Skipping faucet wallet (mainnet)"
fi

echo "Prepared DApps env (CHAIN_ID=${CHAIN_ID_DEC}, explorer v11)"
