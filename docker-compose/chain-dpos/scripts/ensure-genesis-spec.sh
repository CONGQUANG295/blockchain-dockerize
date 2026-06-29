#!/usr/bin/env bash
# Ensure genesis/spec.json is a regular file before OpenEthereum volume mount.
# sync-to-server.sh excludes spec.json (patched on server); Docker creates a directory
# if the mount target is missing — fix by seeding from spec.phase-1.json.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENESIS_DIR="${ROOT_DIR}/genesis"
SPEC="${GENESIS_DIR}/spec.json"
PHASE1="${GENESIS_DIR}/spec.phase-1.json"

if [ -d "${SPEC}" ]; then
  echo "Removing stale genesis/spec.json directory (Docker mount artifact)" >&2
  rm -rf "${SPEC}"
fi

if [ -f "${SPEC}" ]; then
  exit 0
fi

if [ ! -f "${PHASE1}" ]; then
  echo "Missing ${PHASE1} — run prepare-genesis.sh on operator machine first." >&2
  exit 1
fi

cp "${PHASE1}" "${SPEC}"
echo "Seeded genesis/spec.json from spec.phase-1.json"
