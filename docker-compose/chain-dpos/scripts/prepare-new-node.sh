#!/usr/bin/env bash
# Prepare config for a new chain node (RPC or additional validator) from peer bundle.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/peer-config.sh
source "${ROOT_DIR}/scripts/lib/peer-config.sh"
peer_config_paths "${ROOT_DIR}"

NODE_TYPE=""
NODE_ID=""
FORCE_KEYS=false

usage() {
  cat <<'EOF'
Usage: ./scripts/prepare-new-node.sh --type rpc|validator [options]

Uses genesis peer bundle (spec.json + reserved-peers.txt) from seed validator export.
Run export-peer-config.sh on seed host first, or pull-peer-config from operator machine.

Validator nodes: generates keystore (UTC--*), node.pwd, and address automatically
(same as prepare-genesis / gen-validator-account.sh). Re-run is idempotent if keys exist.

Options:
  --type TYPE        rpc | validator (required)
  --node-id ID       Node directory name (default: rpc | next validator-N)
  --force-keys       Regenerate keystore + password (validator only; deletes existing keys)
  -h, --help

Examples:
  ./scripts/prepare-new-node.sh --type rpc
  ./scripts/prepare-new-node.sh --type validator --node-id validator-paris
EOF
}

next_validator_node_id() {
  local root="$1"
  local max=1 n dir
  for dir in "${root}"/nodes/validator-*; do
    [ -d "${dir}" ] || continue
    n="${dir##*/validator-}"
    if [[ "${n}" =~ ^[0-9]+$ ]] && [ "${n}" -gt "${max}" ]; then
      max="${n}"
    fi
  done
  echo "validator-$((max + 1))"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --type) NODE_TYPE="${2:?}"; shift 2 ;;
    --node-id) NODE_ID="${2:?}"; shift 2 ;;
    --force-keys) FORCE_KEYS=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [ -z "${NODE_TYPE}" ]; then
  usage
  exit 1
fi

case "${NODE_TYPE}" in
  rpc)
    NODE_ID="${NODE_ID:-rpc}"
    ;;
  validator)
    NODE_ID="${NODE_ID:-$(next_validator_node_id "${ROOT_DIR}")}"
    ;;
  *)
    echo "Unknown --type: ${NODE_TYPE} (use rpc or validator)" >&2
    exit 1
    ;;
esac

if [ ! -f "${PATH_SPEC}" ]; then
  echo "Missing ${PATH_SPEC}. Export or pull peer bundle from seed validator first." >&2
  exit 1
fi

if [ ! -f "${PATH_GENESIS_RESERVED_PEERS}" ]; then
  if [ -f "${PATH_VALIDATOR_ENODE}" ]; then
    ENODE="$(peer_config_normalize_enode "${PATH_VALIDATOR_ENODE}")"
    peer_config_ensure_dirs
    peer_config_append_reserved_peer "${ENODE}" "${PATH_GENESIS_RESERVED_PEERS}"
    echo "Created ${PATH_GENESIS_RESERVED_PEERS} from validator-1.enode"
  else
    echo "Missing ${PATH_GENESIS_RESERVED_PEERS}. Run export-peer-config.sh on seed host." >&2
    exit 1
  fi
fi

case "${NODE_TYPE}" in
  rpc)
    peer_config_ensure_dirs
    cp "${PATH_TEMPLATES}/rpc.toml.template" "${PATH_RPC_CONFIG}"
    # OpenEthereum v3.3.x RPC namespace is "traces" (plural), not "trace".
    sed -i '/^apis = /s/"trace"/"traces"/g' "${PATH_RPC_CONFIG}"
    cp "${PATH_GENESIS_RESERVED_PEERS}" "${PATH_RESERVED_PEERS}"
    echo "Prepared RPC node:"
    echo "  ${PATH_RPC_CONFIG}"
    echo "  ${PATH_RESERVED_PEERS}"
    ;;
  validator)
    NODE_DIR="${ROOT_DIR}/nodes/${NODE_ID}"
    NODE_CONFIG="${NODE_DIR}/config.toml"
    NODE_RESERVED="${NODE_DIR}/reserved-peers.txt"
    NODE_ADDRESS_FILE="${NODE_DIR}/address"
    NODE_KEYSTORE="${NODE_DIR}/keystore"
    NODE_PASSWORD="${NODE_DIR}/node.pwd"
    mkdir -p "${NODE_KEYSTORE}" "${NODE_DIR}/data"

    if [ "${FORCE_KEYS}" = true ]; then
      rm -f "${NODE_KEYSTORE}"/UTC--* "${NODE_PASSWORD}" "${NODE_ADDRESS_FILE}"
    fi

    if ! command -v node >/dev/null 2>&1; then
      echo "node is required to generate validator keystore." >&2
      exit 1
    fi

    VALIDATOR_ADDRESS="$("${ROOT_DIR}/scripts/gen-validator-account.sh" "${NODE_DIR}")"
    VALIDATOR_ADDRESS="$(echo "${VALIDATOR_ADDRESS}" | tr '[:upper:]' '[:lower:]')"
    echo "${VALIDATOR_ADDRESS}" > "${NODE_ADDRESS_FILE}"

    sed "s/__VALIDATOR_ADDRESS__/${VALIDATOR_ADDRESS}/g" \
      "${PATH_TEMPLATES}/validator-node.toml.template" > "${NODE_CONFIG}"
    cp "${PATH_GENESIS_RESERVED_PEERS}" "${NODE_RESERVED}"

    KEYSTORE_FILE="$(find "${NODE_KEYSTORE}" -maxdepth 1 -name 'UTC--*' -print -quit 2>/dev/null || true)"

    echo "Prepared validator node ${NODE_ID}:"
    echo "  address:   ${VALIDATOR_ADDRESS}"
    echo "  config:    ${NODE_CONFIG}"
    echo "  peers:     ${NODE_RESERVED}"
    echo "  keystore:  ${KEYSTORE_FILE:-${NODE_KEYSTORE}/}"
    echo "  password:  ${NODE_PASSWORD}"
    echo ""
    echo "Next:"
    echo "  1. Fund ${VALIDATOR_ADDRESS} if needed (testnet faucet / transfer)"
    echo "  2. Stake MIN_STAKE via Consensus contract from this wallet"
    echo "  3. Start node; then add its enode to seed: ./scripts/add-peer-enode.sh enode://..."
    echo "  4. Start compose stack for ${NODE_ID} (when compose is defined)"
    ;;
esac
