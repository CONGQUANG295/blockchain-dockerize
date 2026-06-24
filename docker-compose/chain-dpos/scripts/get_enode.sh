#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENESIS_DIR="${ROOT_DIR}/genesis"
RPC_URL="${DPOS_RPC_URL:-http://127.0.0.1:8545}"
OUT_FILE="${GENESIS_DIR}/validator-1.enode"

NODE_INFO="$(curl -sf -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"parity_nodeInfo","params":[],"id":1}' \
  "${RPC_URL}")"

ENODE="$(echo "${NODE_INFO}" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const j=JSON.parse(d); if(j.result&&j.result.enode) console.log(j.result.enode);})")"

if [ -z "${ENODE}" ]; then
  ENODE="$(docker logs "dpos-${NETWORK_TYPE:-testnet}-validator-1" 2>&1 | grep -Eo 'enode://[^ ]+' | head -n 1 || true)"
fi

if [ -z "${ENODE}" ]; then
  echo "Failed to read enode from RPC or container logs" >&2
  exit 1
fi

echo "${ENODE}" > "${OUT_FILE}"
echo "Wrote ${OUT_FILE}: ${ENODE}"
