#!/usr/bin/env bash
# Deprecated — use scripts/local/sync-new-validator.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Deprecated: sync-validator-2.sh → sync-new-validator.sh (set NODE_ID)" >&2
NODE_ID="${NODE_ID:-validator-2}"
exec "${SCRIPT_DIR}/sync-new-validator.sh" "$@" --node-id "${NODE_ID}"
