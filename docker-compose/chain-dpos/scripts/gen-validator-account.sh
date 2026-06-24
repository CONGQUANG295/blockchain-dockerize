#!/usr/bin/env bash
set -euo pipefail

NODE_DIR="${1:?validator node dir required}"
CONTRACTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../blockchain-docker-base/resources/icsc-dpos-contracts" && pwd)"

node "${CONTRACTS_DIR}/scripts/generate-validator-key.js" "${NODE_DIR}"
