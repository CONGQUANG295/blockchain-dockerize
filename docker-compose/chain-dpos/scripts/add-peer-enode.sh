#!/usr/bin/env bash
# Append a peer enode to genesis/reserved-peers.txt and sync to node configs.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/peer-config.sh
source "${ROOT_DIR}/scripts/lib/peer-config.sh"
peer_config_paths "${ROOT_DIR}"

ENODE=""
PEER_ID=""

usage() {
  cat <<'EOF'
Usage: ./scripts/add-peer-enode.sh ENODE [options]

Add a remote peer enode to the network bootstrap list (e.g. new validator came online).

Options:
  --peer-id ID   Also save genesis/peers/<id>.enode
  -h, --help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --peer-id) PEER_ID="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [ -z "${ENODE}" ]; then
        ENODE="$(echo "$1" | tr -d '[:space:]')"
      else
        echo "Unexpected argument: $1" >&2
        usage
        exit 1
      fi
      shift
      ;;
  esac
done

if [ -z "${ENODE}" ]; then
  usage
  exit 1
fi

if [[ ! "${ENODE}" =~ ^enode:// ]]; then
  echo "Expected enode://... URI" >&2
  exit 1
fi

peer_config_ensure_dirs
peer_config_append_reserved_peer "${ENODE}" "${PATH_GENESIS_RESERVED_PEERS}"

if [ -n "${PEER_ID}" ]; then
  printf '%s\n' "${ENODE}" > "${PATH_PEERS_DIR}/${PEER_ID}.enode"
  echo "Wrote ${PATH_PEERS_DIR}/${PEER_ID}.enode"
fi

peer_config_sync_reserved_peers "${ROOT_DIR}"
echo "Added peer to ${PATH_GENESIS_RESERVED_PEERS}"
