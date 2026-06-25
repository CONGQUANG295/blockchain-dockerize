#!/usr/bin/env bash
# Local: pull peer bundle from seed + prepare a new validator node.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${ROOT_DIR}"
SEED_SERVER="${SEED_SERVER:-${SERVER:-}}"
REMOTE_DIR="${REMOTE_DIR:-/opt/blockchain-dock}"
NODE_ID="${NODE_ID:-}"
if [ -z "${SEED_SERVER}" ]; then
  echo "Usage: SEED_SERVER=user@seed-host $0 [NODE_ID=validator-N]" >&2
  echo "  or: make prepare-new-validator-local SEED_SERVER=user@seed-host [NODE_ID=validator-N]" >&2
  exit 1
fi
if [ -n "${NODE_ID}" ]; then
  exec make prepare-new-validator-local \
    SEED_SERVER="${SEED_SERVER}" \
    REMOTE_DIR="${REMOTE_DIR}" \
    NODE_ID="${NODE_ID}"
fi
exec make prepare-new-validator-local \
  SEED_SERVER="${SEED_SERVER}" \
  REMOTE_DIR="${REMOTE_DIR}"
