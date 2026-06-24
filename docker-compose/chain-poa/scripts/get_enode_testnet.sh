#!/bin/sh
ENODE_LINE=$(docker logs poa-testnet-bootnode 2>&1 | grep enode | head -n 1)
echo "enode:${ENODE_LINE#*enode:}"