#!/usr/bin/env bash
# Deferred — new validator / RPC node on remote host (v2)
#
# Operator machine (pull bundle from seed validator):
#   make pull-peer-config SERVER=user@host REMOTE_DIR=/opt/blockchain-gtbs
#   make prepare-new-validator-local SEED_SERVER=user@host [NODE_ID=validator-N]
#   make sync-new-validator SERVER=user@remote NODE_ID=validator-N
#
# Seed validator server (after deploy):
#   ./scripts/export-peer-config.sh
#
# When a new validator joins:
#   ./scripts/add-peer-enode.sh enode://... --peer-id validator-N
#
# Outline:
# 1. Copy genesis bundle (spec.json, reserved-peers.txt, contract-addresses.json)
# 2. prepare-new-node --type validator --node-id <name>  (auto keystore + address)
# 3. Stake MIN_STAKE via Consensus contract
# 4. Start compose stack for the new node (compose TBD)
#
# Not implemented in v1 — single seed validator bootstrap only.
exit 0
