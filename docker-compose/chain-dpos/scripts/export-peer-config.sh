#!/usr/bin/env bash
# Export peer bundle after seed validator deploy: enode, spec, reserved-peers for RPC / new validators.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/peer-config.sh
source "${ROOT_DIR}/scripts/lib/peer-config.sh"
peer_config_paths "${ROOT_DIR}"

PEER_ID="${SEED_PEER_ID:-seed}"
SKIP_ENODE_REFRESH=false
SYNC_ONLY=false

usage() {
  cat <<'EOF'
Usage: ./scripts/export-peer-config.sh [options]

Run on the seed validator host after bootstrap / deploy succeeds.
Writes the peer bundle used to configure RPC nodes and new validators:

  genesis/spec.json                 (already present after patch-spec)
  genesis/contract-addresses.json   (after deploy)
  genesis/flats/                    (GTBS: flattened contracts for Blockscout)
  genesis/gtbs-deploy-config.json   (GTBS: initialize params from env)
  genesis/gtbs-deploy-manifest.json (GTBS: addresses + verify reference)
  genesis/validator-1.enode         (this node's public enode)
  genesis/peers/<peer-id>.enode     (copy of seed enode)
  genesis/reserved-peers.txt        (bootstrap enode list — one per line)
  nodes/rpc/reserved-peers.txt      (synced copy for RPC compose)
  nodes/validator-1/reserved-peers.txt (reference on seed host)

Options:
  --peer-id ID         Peer filename under genesis/peers/ (default: seed)
  --skip-enode-refresh Use existing genesis/validator-1.enode
  --sync-only          Only sync reserved-peers.txt to node dirs
  -h, --help

Environment (envs/deploy.env):
  P2P_PUBLIC_IP, OPEN_P2P_PORT, P2P_PORT
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --peer-id) PEER_ID="${2:?}"; shift 2 ;;
    --skip-enode-refresh) SKIP_ENODE_REFRESH=true; shift ;;
    --sync-only) SYNC_ONLY=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

cd "${ROOT_DIR}"
peer_config_ensure_dirs

if [ "${SYNC_ONLY}" = false ]; then
  if [ "${SKIP_ENODE_REFRESH}" = false ]; then
    ./scripts/get_enode.sh
  elif [ ! -f "${PATH_VALIDATOR_ENODE}" ]; then
    echo "Missing ${PATH_VALIDATOR_ENODE} — run without --skip-enode-refresh" >&2
    exit 1
  fi

  ENODE="$(peer_config_normalize_enode "${PATH_VALIDATOR_ENODE}")"
  cp "${PATH_VALIDATOR_ENODE}" "${PATH_PEERS_DIR}/${PEER_ID}.enode"
  peer_config_append_reserved_peer "${ENODE}" "${PATH_GENESIS_RESERVED_PEERS}"
  echo "Wrote ${PATH_PEERS_DIR}/${PEER_ID}.enode"
  echo "Updated ${PATH_GENESIS_RESERVED_PEERS}"
fi

peer_config_sync_reserved_peers "${ROOT_DIR}"

echo ""
echo "Peer bundle ready:"
peer_config_list_bundle_files "${ROOT_DIR}" | while IFS= read -r f; do
  [ -f "${f}" ] && echo "  ${f}"
done
echo ""
echo "Configure new nodes locally:"
echo "  ./scripts/prepare-new-node.sh --type rpc"
echo "  ./scripts/prepare-new-node.sh --type validator --node-id validator-N"
echo "Or pull from operator machine:"
echo "  make pull-peer-config SERVER=user@host REMOTE_DIR=..."
