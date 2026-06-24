#!/usr/bin/env bash
# Deferred — validator-2 remote setup (v2)
#
# Outline:
# 1. Copy genesis bundle to remote host:
#    - genesis/spec.json (final phase-2)
#    - genesis/validator-1.enode (for reserved_peers)
#    - genesis/contract-addresses.json
# 2. SSH: import validator-2 keystore, set reserved_peers to validator-1 enode
# 3. Stake MIN_STAKE via Consensus contract from validator-2 wallet
# 4. Start compose-validator-2.yml (stub)
#
# Not implemented in v1 — single validator bootstrap only.
exit 0
