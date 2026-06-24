#!/usr/bin/env bash
set -euo pipefail

GENESIS_DIR="${1:?genesis dir required}"
VALIDATOR_DIR="${GENESIS_DIR}/validator-1"
CONTRACTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../blockchain-docker-base/resources/icsc-dpos-contracts" && pwd)"

node "${CONTRACTS_DIR}/scripts/generate-validator-key.js" "${VALIDATOR_DIR}"
