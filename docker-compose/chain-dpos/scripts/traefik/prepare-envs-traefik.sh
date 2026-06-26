#!/usr/bin/env bash
set -euo pipefail

CHAIN_DPOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${CHAIN_DPOS_DIR}"

if [ ! -e envs/traefik.env ]; then
  cp envs/traefik.env.example envs/traefik.env
  echo "Created envs/traefik.env — edit domains and ACME_EMAIL before starting Traefik."
fi

mkdir -p data/traefik/letsencrypt data/proxy/docs
if [ ! -f data/proxy/docs/index.html ]; then
  cp ../proxy_custom_html/index.html data/proxy/docs/index.html 2>/dev/null || \
    echo '<!DOCTYPE html><html><body><h1>Docs</h1></body></html>' > data/proxy/docs/index.html
fi
if [ ! -f data/traefik/letsencrypt/acme.json ]; then
  touch data/traefik/letsencrypt/acme.json
  chmod 600 data/traefik/letsencrypt/acme.json
fi

echo "Traefik env ready."
