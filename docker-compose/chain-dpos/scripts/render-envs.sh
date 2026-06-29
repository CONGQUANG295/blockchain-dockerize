#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib-images.sh
source "${ROOT_DIR}/scripts/lib-images.sh"
# shellcheck source=lib/wei-math.sh
source "${ROOT_DIR}/scripts/lib/wei-math.sh"
WITH_TRAEFIK=false
DEPLOY_ENV=""

while [ $# -gt 0 ]; do
  case "$1" in
    --with-traefik) WITH_TRAEFIK=true ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) DEPLOY_ENV="$1" ;;
  esac
  shift
done

DEPLOY_ENV="${DEPLOY_ENV:-${ROOT_DIR}/envs/deploy.env}"
if [ ! -f "${DEPLOY_ENV}" ]; then
  echo "Missing ${DEPLOY_ENV}. Copy envs/deploy.env.example first." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${DEPLOY_ENV}"
set +a

gen_hex() { openssl rand -hex 32; }

POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(gen_hex)}"
POSTGRES_DB="${POSTGRES_DB:-blockscout}"
SECRET_KEY_BASE="${SECRET_KEY_BASE:-$(openssl rand -hex 64)}"
WS_SECRET="${WS_SECRET:-$(gen_hex)}"

: "${NETWORK_NAME:?NETWORK_NAME required}"
: "${NETWORK_ID:?NETWORK_ID required}"
: "${PREMINE_ADDRESS:?PREMINE_ADDRESS required}"
: "${PREMINE_BALANCE_WEI:?PREMINE_BALANCE_WEI required}"

NETWORK_TYPE="${NETWORK_TYPE:-testnet}"
BLOCK_TIME_SECONDS="${BLOCK_TIME_SECONDS:-5}"
CONTRACT_TRANSITION_BLOCK="${CONTRACT_TRANSITION_BLOCK:-100}"
VALIDATOR_BALANCE_WEI="${VALIDATOR_BALANCE_WEI:-10000000000000000000000}"
INITIAL_SUPPLY_GWEI="$(wei_div_gwei "${PREMINE_BALANCE_WEI}")"
BLOCKS_PER_YEAR=$(( 31536000 / BLOCK_TIME_SECONDS ))

if [ $(( 31536000 % BLOCK_TIME_SECONDS )) -ne 0 ]; then
  echo "BLOCK_TIME_SECONDS must divide 31536000 evenly (got ${BLOCK_TIME_SECONDS})" >&2
  exit 1
fi

if [ "${ENABLE_CUSTOM_STAKING:-false}" = "true" ]; then
  : "${MAX_SUPPLY_WEI:?MAX_SUPPLY_WEI required when ENABLE_CUSTOM_STAKING=true}"
fi

if [ "${WITH_TRAEFIK}" = true ]; then
  : "${EXPLORER_SERVER_NAME:?}"
  : "${STATS_SERVER_NAME:?}"
  : "${VISUALIZE_SERVER_NAME:?}"
  : "${ACME_EMAIL:?}"
  : "${RPC_SERVER_NAME:?}"
fi

if [ "${NETWORK_TYPE}" = mainnet ] && [ "${WITH_TRAEFIK}" = true ]; then
  : "${STATUS_SERVER_NAME:?}"
  : "${DOCS_SERVER_NAME:?}"
fi

CHAIN_ID_DEC=$((16#${NETWORK_ID#0x}))
COIN_NAME="${COIN_NAME:-Coin}"
COIN_SYMBOL="${COIN_SYMBOL:-COIN}"
NEXT_PUBLIC_IS_TESTNET="${NEXT_PUBLIC_IS_TESTNET:-$([ "${NETWORK_TYPE}" = testnet ] && echo true || echo false)}"
EXPLORER_ASSETS_BASE_URL="${EXPLORER_ASSETS_BASE_URL:-https://raw.githubusercontent.com/gtbschain/assets/master/explorer}"

ENVS_DIR="${ROOT_DIR}/envs"
mkdir -p "${ENVS_DIR}"

cat > "${ENVS_DIR}/dpos.chain.env" <<EOF
NETWORK_NAME=${NETWORK_NAME}
NETWORK_ID=${NETWORK_ID}
NETWORK_TYPE=${NETWORK_TYPE}
BLOCK_TIME_SECONDS=${BLOCK_TIME_SECONDS}
CONTRACT_TRANSITION_BLOCK=${CONTRACT_TRANSITION_BLOCK}
PREMINE_ADDRESS=${PREMINE_ADDRESS}
PREMINE_BALANCE_WEI=${PREMINE_BALANCE_WEI}
VALIDATOR_BALANCE_WEI=${VALIDATOR_BALANCE_WEI}
INITIAL_SUPPLY_GWEI=${INITIAL_SUPPLY_GWEI}
MAX_SUPPLY_WEI=${MAX_SUPPLY_WEI:-}
EOF

if [ "${ENABLE_EIP1559:-false}" = "true" ]; then
  {
    echo ""
    echo "# EIP-1559 (rendered from deploy.env)"
    echo "ENABLE_EIP1559=true"
    echo "EIP1559_TRANSITION_BLOCK=${EIP1559_TRANSITION_BLOCK:-0}"
    echo "EIP1559_BASE_FEE_INITIAL_VALUE=${EIP1559_BASE_FEE_INITIAL_VALUE:-0x3B9ACA00}"
    echo "EIP1559_BASE_FEE_MAX_CHANGE_DENOMINATOR=${EIP1559_BASE_FEE_MAX_CHANGE_DENOMINATOR:-0x8}"
    echo "EIP1559_ELASTICITY_MULTIPLIER=${EIP1559_ELASTICITY_MULTIPLIER:-0x2}"
    [ -n "${EIP1559_BASE_FEE_MIN_VALUE:-}" ] && \
      echo "EIP1559_BASE_FEE_MIN_VALUE=${EIP1559_BASE_FEE_MIN_VALUE}"
    [ -n "${EIP1559_BASE_FEE_MIN_VALUE_TRANSITION:-}" ] && \
      echo "EIP1559_BASE_FEE_MIN_VALUE_TRANSITION=${EIP1559_BASE_FEE_MIN_VALUE_TRANSITION}"
    [ -n "${EIP1559_FEE_COLLECTOR:-}" ] && \
      echo "EIP1559_FEE_COLLECTOR=${EIP1559_FEE_COLLECTOR}"
    [ -n "${EIP1559_FEE_COLLECTOR_TRANSITION:-}" ] && \
      echo "EIP1559_FEE_COLLECTOR_TRANSITION=${EIP1559_FEE_COLLECTOR_TRANSITION}"
  } >> "${ENVS_DIR}/dpos.chain.env"
fi

cat > "${ENVS_DIR}/dpos.contract.env" <<EOF
DECIMALS=${DECIMALS:-18}
MIN_STAKE_TOKENS=${MIN_STAKE_TOKENS:-100000}
MAX_STAKE_TOKENS=${MAX_STAKE_TOKENS:-25000000}
DEFAULT_VALIDATOR_FEE_PERCENT=${DEFAULT_VALIDATOR_FEE_PERCENT:-15}
BLOCK_TIME_SECONDS=${BLOCK_TIME_SECONDS}
CYCLE_DURATION_SECONDS=${CYCLE_DURATION_SECONDS:-172800}
INFLATION_PERCENT=${INFLATION_PERCENT:-5}
EOF

if [ "${ENABLE_CUSTOM_STAKING:-false}" = "true" ]; then
  GTBS_SRC="${ROOT_DIR}/../../../blockchain-docker-base/resources/custom-staking-contracts/env/gtbs-staking.env.example"
  if [ -f "${GTBS_SRC}" ]; then
    cp "${GTBS_SRC}" "${ENVS_DIR}/gtbs-staking.env"
    # Override from deploy.env when set
    for key in MAX_STAKE_TOKENS MIN_STAKE_TOKENS NET_APY_PERCENT ANNUAL_UNLOCK_CAP_TOKENS UNSTAKE_FEE_BPS DELEGATOR_LOCK_DAYS ANNUAL_UNLOCK_PERIOD_DAYS RELEASE_DELAY_DAYS BLOCK_TIME_SECONDS; do
      val="${!key:-}"
      if [ -n "${val}" ]; then
        if grep -q "^${key}=" "${ENVS_DIR}/gtbs-staking.env"; then
          sed -i "s|^${key}=.*|${key}=${val}|" "${ENVS_DIR}/gtbs-staking.env"
        else
          echo "${key}=${val}" >> "${ENVS_DIR}/gtbs-staking.env"
        fi
      fi
    done
    if grep -q "^BLOCKS_PER_YEAR=" "${ENVS_DIR}/gtbs-staking.env"; then
      sed -i "s|^BLOCKS_PER_YEAR=.*|BLOCKS_PER_YEAR=${BLOCKS_PER_YEAR}|" "${ENVS_DIR}/gtbs-staking.env"
    else
      echo "BLOCKS_PER_YEAR=${BLOCKS_PER_YEAR}" >> "${ENVS_DIR}/gtbs-staking.env"
    fi
  fi
fi

cat > "${ENVS_DIR}/db.env" <<EOF
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
EOF

_OPENETHEREUM_IMAGE="${OPENETHEREUM_IMAGE:-}"
_VALIDATOR_APP_IMAGE="${VALIDATOR_APP_IMAGE:-}"
_DPOS_DEPLOYER_IMAGE="${DPOS_DEPLOYER_IMAGE:-}"
_BLOCKSCOUT_BACKEND_IMAGE="${BLOCKSCOUT_BACKEND_IMAGE:-}"
_BLOCKSCOUT_FRONTEND_IMAGE="${BLOCKSCOUT_FRONTEND_IMAGE:-}"
_BLOCKSCOUT_STATS_IMAGE="${BLOCKSCOUT_STATS_IMAGE:-}"
_BLOCKSCOUT_VISUALIZER_IMAGE="${BLOCKSCOUT_VISUALIZER_IMAGE:-}"
_NETSTATS_API_IMAGE="${NETSTATS_API_IMAGE:-}"
_NETSTATS_DASHBOARD_IMAGE="${NETSTATS_DASHBOARD_IMAGE:-}"
_ETH_FAUCET_IMAGE="${ETH_FAUCET_IMAGE:-}"
_DOCS_IMAGE="${DOCS_IMAGE:-}"

OPENETHEREUM_IMAGE="$(resolve_image "${_OPENETHEREUM_IMAGE}" openethereum 0.0.1 openethereum)"
VALIDATOR_APP_IMAGE="$(resolve_image "${_VALIDATOR_APP_IMAGE}" validator-app 0.0.1 validator-app)"
DPOS_DEPLOYER_IMAGE="$(resolve_image "${_DPOS_DEPLOYER_IMAGE}" dpos-deployer 0.0.1 dpos-deployer)"
BLOCKSCOUT_BACKEND_IMAGE="$(resolve_image "${_BLOCKSCOUT_BACKEND_IMAGE}" blockscout-backend 11.2.1 blockscout-backend)"
BLOCKSCOUT_FRONTEND_IMAGE="$(resolve_image "${_BLOCKSCOUT_FRONTEND_IMAGE}" blockscout-frontend 2.8.1 blockscout-frontend)"
BLOCKSCOUT_STATS_IMAGE="${_BLOCKSCOUT_STATS_IMAGE:-ghcr.io/blockscout/stats:latest}"
BLOCKSCOUT_VISUALIZER_IMAGE="${_BLOCKSCOUT_VISUALIZER_IMAGE:-ghcr.io/blockscout/visualizer:latest}"
NETSTATS_API_IMAGE="$(resolve_image "${_NETSTATS_API_IMAGE}" netstats-api 0.0.1 netstats-api)"
NETSTATS_DASHBOARD_IMAGE="$(resolve_image "${_NETSTATS_DASHBOARD_IMAGE}" netstats-dashboard 0.0.1 netstats-dashboard)"
ETH_FAUCET_IMAGE="$(resolve_image "${_ETH_FAUCET_IMAGE}" eth-faucet 0.0.1 eth-faucet)"
DOCS_IMAGE="$(resolve_image "${_DOCS_IMAGE}" docs-poa 0.0.1 docs-poa)"

cat > "${ENVS_DIR}/images.env" <<EOF
OPENETHEREUM_IMAGE=${OPENETHEREUM_IMAGE}
VALIDATOR_APP_IMAGE=${VALIDATOR_APP_IMAGE}
DPOS_DEPLOYER_IMAGE=${DPOS_DEPLOYER_IMAGE}
BLOCKSCOUT_BACKEND_IMAGE=${BLOCKSCOUT_BACKEND_IMAGE}
BLOCKSCOUT_FRONTEND_IMAGE=${BLOCKSCOUT_FRONTEND_IMAGE}
BLOCKSCOUT_STATS_IMAGE=${BLOCKSCOUT_STATS_IMAGE}
BLOCKSCOUT_VISUALIZER_IMAGE=${BLOCKSCOUT_VISUALIZER_IMAGE}
NETSTATS_API_IMAGE=${NETSTATS_API_IMAGE}
NETSTATS_DASHBOARD_IMAGE=${NETSTATS_DASHBOARD_IMAGE}
ETH_FAUCET_IMAGE=${ETH_FAUCET_IMAGE}
DOCS_IMAGE=${DOCS_IMAGE}
EOF

STATS_DB_PASSWORD="${STATS_DB_PASSWORD:-$(gen_hex)}"

cat > "${ENVS_DIR}/blockscout-backend.env" <<EOF
SECRET_KEY_BASE=${SECRET_KEY_BASE}
DATABASE_URL=postgresql://blockscout:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}?sslmode=disable
ETHEREUM_JSONRPC_VARIANT=nethermind
BLOCK_TRANSFORMER=base
ETHEREUM_JSONRPC_HTTP_URL=http://rpc.host:8545/
ETHEREUM_JSONRPC_TRACE_URL=http://rpc.host:8545/
ETHEREUM_JSONRPC_WS_URL=ws://rpc.host:8546/
CHAIN_ID=${CHAIN_ID_DEC}
COIN=${COIN_SYMBOL}
COIN_NAME=${COIN_NAME}
DISABLE_MARKET=true
POOL_SIZE=80
POOL_SIZE_API=20
INDEXER_DISABLE_INTERNAL_TRANSACTIONS_FETCHER=true
INDEXER_DISABLE_PENDING_TRANSACTIONS_FETCHER=true
INDEXER_RECEIPTS_CONCURRENCY=5
INDEXER_CATCHUP_BLOCKS_CONCURRENCY=5
EOF

cat > "${ENVS_DIR}/rpc.env" <<EOF
OE_CONFIG_PATH=/app/config/config.toml
EOF

# Append Blockscout address display envs to blockscout-frontend.env (Option A: native bech32)
append_address_display_envs() {
  local prefix="${ADDRESS_DISPLAY_PREFIX:-}"
  local default_fmt="${ADDRESS_DISPLAY_DEFAULT:-bech32}"
  local toggle="${ADDRESS_FORMAT_TOGGLE:-true}"

  [ -n "${prefix}" ] || return 0

  local prefix_len=${#prefix}
  if [ "${prefix_len}" -lt 1 ] || [ "${prefix_len}" -gt 83 ]; then
    echo "ADDRESS_DISPLAY_PREFIX must be 1–83 characters (got length ${prefix_len})" >&2
    exit 1
  fi

  local format_json=""
  if [ "${toggle}" = true ]; then
    if [ "${default_fmt}" = base16 ]; then
      format_json="['base16','bech32']"
    else
      format_json="['bech32','base16']"
    fi
  else
    if [ "${default_fmt}" = base16 ]; then
      format_json="['base16']"
    else
      format_json="['bech32']"
    fi
  fi

  echo "NEXT_PUBLIC_VIEWS_ADDRESS_FORMAT=${format_json}" >> "${ENVS_DIR}/blockscout-frontend.env"

  case "${format_json}" in
    *bech32*)
      echo "NEXT_PUBLIC_VIEWS_ADDRESS_BECH_32_PREFIX=${prefix}" >> "${ENVS_DIR}/blockscout-frontend.env"
      ;;
  esac
}

cat > "${ENVS_DIR}/blockscout-frontend.env" <<EOF
NEXT_PUBLIC_API_HOST=${EXPLORER_SERVER_NAME:-explorer.local}
NEXT_PUBLIC_API_PROTOCOL=https
NEXT_PUBLIC_APP_HOST=${EXPLORER_SERVER_NAME:-explorer.local}
NEXT_PUBLIC_APP_PROTOCOL=https
NEXT_PUBLIC_API_BASE_PATH=/
NEXT_PUBLIC_API_WEBSOCKET_PROTOCOL=wss
NEXT_PUBLIC_STATS_API_HOST=https://${STATS_SERVER_NAME:-stats.local}
NEXT_PUBLIC_VISUALIZE_API_HOST=https://${VISUALIZE_SERVER_NAME:-visualize.local}
NEXT_PUBLIC_NETWORK_NAME=${NETWORK_NAME}
NEXT_PUBLIC_NETWORK_SHORT_NAME=${COIN_SYMBOL}
NEXT_PUBLIC_NETWORK_ID=${CHAIN_ID_DEC}
NEXT_PUBLIC_NETWORK_CURRENCY_NAME=${COIN_NAME}
NEXT_PUBLIC_NETWORK_CURRENCY_SYMBOL=${COIN_SYMBOL}
NEXT_PUBLIC_NETWORK_CURRENCY_DECIMALS=18
NEXT_PUBLIC_IS_TESTNET=${NEXT_PUBLIC_IS_TESTNET}
NEXT_PUBLIC_BLOCK_TIME_SECONDS=${BLOCK_TIME_SECONDS}
NEXT_PUBLIC_HOMEPAGE_CHARTS=['daily_txs']
EOF

append_address_display_envs

if [ "${EXPLORER_CUSTOM_PROFILE:-}" != "gtbs" ]; then
  cat >> "${ENVS_DIR}/blockscout-frontend.env" <<EOF
NEXT_PUBLIC_FOOTER_PROJECT_CONFIG={"title":"Powered by ${COIN_NAME}","description":"Block explorer for ${NETWORK_NAME}.","copyright":"${COIN_NAME}"}
EOF
fi

if [ -n "${EXPLORER_HERO_TITLE:-}" ]; then
  echo "NEXT_PUBLIC_HOMEPAGE_HERO_TITLE=${EXPLORER_HERO_TITLE}" >> "${ENVS_DIR}/blockscout-frontend.env"
fi

if [ "${EXPLORER_CUSTOM_PROFILE:-}" = "gtbs" ]; then
  GTBS_FRONTEND_EXAMPLE="${ROOT_DIR}/envs/blockscout-frontend.gtbs.env.example"
  GTBS_BACKEND_EXAMPLE="${ROOT_DIR}/envs/blockscout-backend.gtbs.env.example"
  CONSENSUS_PROXY="0x0000000000000000000000000000000000000000"
  STAKING_VAULT_PROXY=""
  if [ -f "${ROOT_DIR}/genesis/contract-addresses.json" ] && command -v jq >/dev/null; then
    _consensus="$(jq -r '.consensusProxy // empty' "${ROOT_DIR}/genesis/contract-addresses.json")"
    [ -n "${_consensus}" ] && CONSENSUS_PROXY="${_consensus}"
    _staking="$(jq -r '.stakingVault // empty' "${ROOT_DIR}/genesis/contract-addresses.json")"
    [ -n "${_staking}" ] && STAKING_VAULT_PROXY="${_staking}"
  fi
  export CONSENSUS_PROXY STAKING_VAULT_PROXY RPC_SERVER_NAME EXPLORER_SERVER_NAME EXPLORER_ASSETS_BASE_URL COIN_SYMBOL NETWORK_NAME
  if [ -f "${GTBS_FRONTEND_EXAMPLE}" ]; then
    grep -v '^#' "${GTBS_FRONTEND_EXAMPLE}" | grep -v '^$' | envsubst >> "${ENVS_DIR}/blockscout-frontend.env"
  fi
  if [ -f "${GTBS_BACKEND_EXAMPLE}" ]; then
    grep -v '^#' "${GTBS_BACKEND_EXAMPLE}" | grep -v '^$' | envsubst >> "${ENVS_DIR}/blockscout-backend.env"
  fi
fi

cat > "${ENVS_DIR}/blockscout-stats.env" <<EOF
STATS_DB_PASSWORD=${STATS_DB_PASSWORD}
POSTGRES_PASSWORD=${STATS_DB_PASSWORD}
STATS__DB_URL=postgres://stats:${STATS_DB_PASSWORD}@stats-db:5432/stats
STATS__BLOCKSCOUT_DB_URL=postgresql://blockscout:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}?sslmode=disable
STATS__CREATE_DATABASE=true
STATS__RUN_MIGRATIONS=true
STATS__BLOCKSCOUT_API_URL=http://backend:4000
EOF

cat > "${ENVS_DIR}/blockscout-visualizer.env" <<EOF
VISUALIZER__SERVER__HTTP__ENABLED=true
VISUALIZER__SERVER__HTTP__ADDR=0.0.0.0:8050
EOF

cat > "${ENVS_DIR}/traefik.env" <<EOF
ACME_EMAIL=${ACME_EMAIL:-admin@example.com}
TRAEFIK_LOG_LEVEL=${TRAEFIK_LOG_LEVEL:-INFO}
TRAEFIK_DASHBOARD_ENABLED=${TRAEFIK_DASHBOARD_ENABLED:-true}
TRAEFIK_DASHBOARD_HOST=${TRAEFIK_DASHBOARD_HOST:-traefik.local}
NETWORK_TYPE=${NETWORK_TYPE}
RPC_SERVER_NAME=${RPC_SERVER_NAME:-rpc.local}
EXPLORER_SERVER_NAME=${EXPLORER_SERVER_NAME:-explorer.local}
STATS_SERVER_NAME=${STATS_SERVER_NAME:-stats.local}
VISUALIZE_SERVER_NAME=${VISUALIZE_SERVER_NAME:-visualize.local}
BLOCKSCOUT_BACK_SERVER_NAME=${EXPLORER_SERVER_NAME:-explorer.local}
STATUS_SERVER_NAME=${STATUS_SERVER_NAME:-status.local}
FAUCET_SERVER_NAME=${FAUCET_SERVER_NAME:-faucet.local}
DOCS_SERVER_NAME=${DOCS_SERVER_NAME:-docs.local}
EOF

cat > "${ENVS_DIR}/netstats-dashboard.env" <<EOF
WS_SECRET=${WS_SECRET}
WS_HOST=host.docker.internal
PORT=3006
PAGE_TITLE=${NETSTATS_PAGE_TITLE:-${COIN_NAME} Network Status}
FAVICON_URL=${NETSTATS_FAVICON_URL:-${EXPLORER_ASSETS_BASE_URL}/symbol.svg}
EOF

cat > "${ENVS_DIR}/netstats-api.env" <<EOF
WS_SECRET=${WS_SECRET}
WS_SERVER=wss://${STATUS_SERVER_NAME:-status.local}
EOF

# Legacy blockscout v4 env (CHAIN_ID only) for any tooling still reading it
cat > "${ENVS_DIR}/blockscout.env" <<EOF
CHAIN_ID=${CHAIN_ID_DEC}
SECRET_KEY_BASE=${SECRET_KEY_BASE}
ETHEREUM_JSONRPC_VARIANT=openethereum
EOF

echo "Rendered env files from ${DEPLOY_ENV}"
