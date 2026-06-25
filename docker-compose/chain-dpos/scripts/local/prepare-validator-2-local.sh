#!/usr/bin/env bash
# Deprecated — use scripts/local/prepare-new-validator-local.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Deprecated: prepare-validator-2-local.sh → prepare-new-validator-local.sh" >&2
exec "${SCRIPT_DIR}/prepare-new-validator-local.sh" "$@"
