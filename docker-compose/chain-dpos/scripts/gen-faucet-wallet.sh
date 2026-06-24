#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPORT="${ROOT_DIR}/genesis/faucet-wallet.export"
ENV_FILE="${ROOT_DIR}/envs/eth-faucet.env"
CONTRACTS_DIR="$(cd "${ROOT_DIR}/../../../../blockchain-docker-base/resources/icsc-dpos-contracts" && pwd)"

set -a
# shellcheck disable=SC1090
source "${ROOT_DIR}/envs/dpos.chain.env"
set +a

if [ "${NETWORK_TYPE}" != testnet ]; then
  echo "Faucet wallet generation skipped (NETWORK_TYPE=${NETWORK_TYPE}, testnet only)"
  exit 0
fi

if [ -f "${EXPORT}" ] && [ -f "${ENV_FILE}" ] && grep -q '^PRIVATE_KEY=.\+' "${ENV_FILE}"; then
  echo "Faucet wallet exists (${EXPORT}), skip regen"
  exit 0
fi

(
  cd "${CONTRACTS_DIR}"
  node - "${EXPORT}" "${ENV_FILE}" <<'NODE'
const { Wallet } = require("ethers");
const fs = require("fs");
const exportPath = process.argv[2];
const envPath = process.argv[3];
const w = Wallet.createRandom();
fs.writeFileSync(
  exportPath,
  JSON.stringify(
    { address: w.address, privateKey: w.privateKey, createdAt: new Date().toISOString() },
    null,
    2
  )
);
fs.writeFileSync(envPath, `WEB3_PROVIDER=http://rpc.host:8545\nPRIVATE_KEY=${w.privateKey}\n`);
console.log(w.address);
NODE
)

echo "Faucet wallet exported to ${EXPORT} — back up this file."
