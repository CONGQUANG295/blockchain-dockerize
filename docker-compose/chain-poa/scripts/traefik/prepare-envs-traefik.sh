#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHAIN_POA_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${CHAIN_POA_DIR}"

# Reuse existing dapps env preparation (db, blockscout, faucet, ...).
./scripts/v4/prepare-envs-dapps.sh

if [ ! -e envs/traefik.env ]; then
  cp envs/traefik.env.example envs/traefik.env
  echo "Created envs/traefik.env — edit domains and ACME_EMAIL before starting Traefik."
fi

mkdir -p ../../data/traefik/letsencrypt
if [ ! -f ../../data/traefik/letsencrypt/acme.json ]; then
  touch ../../data/traefik/letsencrypt/acme.json
  chmod 600 ../../data/traefik/letsencrypt/acme.json
fi

mkdir -p ../../data/proxy/docs

"${SCRIPT_DIR}/generate-dynamic-config.sh"

echo "Traefik env ready. Next: docker compose -f compose-dapps-traefik-v4.yml config"
