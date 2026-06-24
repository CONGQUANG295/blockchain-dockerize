# shellcheck shell=bash
# Unified runtime paths for chain-dpos (source from scripts).

chain_dpos_paths() {
  local root="${1:?chain-dpos root required}"
  CHAIN_DPOS_ROOT="${root}"
  PATH_GENESIS="${root}/genesis"
  PATH_DATA="${root}/data"
  PATH_TEMPLATES="${root}/templates"
  PATH_NODE_VALIDATOR="${root}/nodes/validator-1"
  PATH_NODE_RPC="${root}/nodes/rpc"
  PATH_VALIDATOR_CONFIG="${PATH_NODE_VALIDATOR}/config.toml"
  PATH_RPC_CONFIG="${PATH_NODE_RPC}/config.toml"
  PATH_RESERVED_PEERS="${PATH_NODE_RPC}/reserved-peers.txt"
  PATH_VALIDATOR_KEYSTORE="${PATH_NODE_VALIDATOR}/keystore"
  PATH_VALIDATOR_PASSWORD="${PATH_NODE_VALIDATOR}/node.pwd"
  PATH_VALIDATOR_DATA="${PATH_NODE_VALIDATOR}/data"
  PATH_RPC_DATA="${PATH_NODE_RPC}/data"
  PATH_VALIDATOR_ADDRESS="${PATH_GENESIS}/validator-1.address"
  PATH_VALIDATOR_ENODE="${PATH_GENESIS}/validator-1.enode"
  PATH_SPEC="${PATH_GENESIS}/spec.json"
  PATH_CONTRACT_ADDRESSES="${PATH_GENESIS}/contract-addresses.json"

  # Container paths (same for every service)
  CONTAINER_SPEC="/app/genesis/spec.json"
  CONTAINER_CONFIG="/app/config/config.toml"
  CONTAINER_PASSWORD="/app/secrets/node.pwd"
  CONTAINER_KEYSTORE="/app/keys"
  CONTAINER_CHAIN_DATA="/app/data"
  CONTAINER_RESERVED_PEERS="/app/config/reserved-peers.txt"
  CONTAINER_GENESIS="/app/genesis"
}

chain_dpos_ensure_node_dirs() {
  mkdir -p \
    "${PATH_NODE_VALIDATOR}/keystore" \
    "${PATH_NODE_VALIDATOR}/data" \
    "${PATH_NODE_RPC}/data"
}
