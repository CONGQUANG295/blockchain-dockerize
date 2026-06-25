#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENESIS_DIR="${ROOT_DIR}/genesis"
ENVS_DIR="${ROOT_DIR}/envs"
RPC_URL="${DPOS_RPC_URL:-http://127.0.0.1:8545}"
OUT_FILE="${GENESIS_DIR}/validator-1.enode"

set -a
# shellcheck disable=SC1090
source "${ENVS_DIR}/dpos.chain.env"
# shellcheck disable=SC1090
source "${ENVS_DIR}/deploy.env" 2>/dev/null || true
set +a

CONTAINER_NAME="dpos-${NETWORK_TYPE:-testnet}-validator-1"

read_enode_from_rpc() {
  local method="$1"
  local response
  response="$(curl -sf -X POST -H "Content-Type: application/json" \
    --data "{\"jsonrpc\":\"2.0\",\"method\":\"${method}\",\"params\":[],\"id\":1}" \
    "${RPC_URL}" 2>/dev/null || true)"
  if [ -z "${response}" ]; then
    return 1
  fi
  if echo "${response}" | jq -e '.error' >/dev/null 2>&1; then
    return 1
  fi
  local enode
  enode="$(echo "${response}" | jq -r '.result.enode // empty')"
  if [ -n "${enode}" ] && [ "${enode}" != "null" ]; then
    echo "${enode}"
    return 0
  fi
  return 1
}

ENODE=""
for rpc_method in parity_nodeInfo admin_nodeInfo; do
  if ENODE="$(read_enode_from_rpc "${rpc_method}")"; then
    echo "Read enode via RPC ${rpc_method}"
    break
  fi
done

if [ -z "${ENODE}" ]; then
  if docker ps --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
    ENODE="$(docker logs "${CONTAINER_NAME}" 2>&1 | grep -Eo 'enode://[0-9a-fA-F@.:]+' | head -n 1 || true)"
    if [ -n "${ENODE}" ]; then
      echo "Read enode from container logs (${CONTAINER_NAME})"
    fi
  fi
fi

if [ -z "${ENODE}" ]; then
  echo "Failed to read enode from RPC (${RPC_URL}) or container logs (${CONTAINER_NAME})" >&2
  echo "Hints:" >&2
  echo "  - docker ps --filter name=validator-1" >&2
  echo "  - curl -s -X POST -H 'Content-Type: application/json' --data '{\"jsonrpc\":\"2.0\",\"method\":\"parity_nodeInfo\",\"params\":[],\"id\":1}' ${RPC_URL} | jq ." >&2
  exit 1
fi

if [ "${OPEN_P2P_PORT:-}" = "1" ] || [ "${OPEN_P2P_PORT:-}" = "true" ] || [ -n "${P2P_PUBLIC_IP:-}" ]; then
  # shellcheck source=lib/open-p2p-firewall.sh
  source "${ROOT_DIR}/scripts/lib/open-p2p-firewall.sh"
  PUBLIC_IP="${P2P_PUBLIC_IP:-}"
  if [ -z "${PUBLIC_IP}" ]; then
    PUBLIC_IP="$(resolve_p2p_public_ip || true)"
  fi
  if [ -n "${PUBLIC_IP}" ]; then
    ENODE="$(rewrite_enode_public_ip "${ENODE}" "${PUBLIC_IP}")"
    echo "Enode public IP: ${PUBLIC_IP}"
  else
    echo "Warning: set P2P_PUBLIC_IP in deploy.env — could not auto-detect public IP" >&2
  fi
fi

echo "${ENODE}" > "${OUT_FILE}"
echo "Wrote ${OUT_FILE}: ${ENODE}"
