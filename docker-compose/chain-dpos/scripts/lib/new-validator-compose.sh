# shellcheck shell=bash
# Generate compose + env files for a non-seed validator (source from scripts).

new_validator_compose_paths() {
  local root="${1:?chain-dpos root required}"
  local node_id="${2:?NODE_ID required}"
  NV_ROOT="${root}"
  NV_NODE_ID="${node_id}"
  NV_NODE_DIR="${root}/nodes/${node_id}"
  NV_ENV_FILE="${root}/envs/${node_id}.env"
  NV_OVERRIDE="${root}/overrides/${node_id}.override.yml"
  NV_COMPOSE="${root}/compose-${node_id}.yml"
}

new_validator_require_node() {
  local root="$1"
  local node_id="$2"
  new_validator_compose_paths "${root}" "${node_id}"
  if [ ! -d "${NV_NODE_DIR}" ]; then
    echo "Missing ${NV_NODE_DIR} — run prepare-new-validator-local on operator machine first." >&2
    return 1
  fi
  if [ ! -f "${NV_NODE_DIR}/address" ]; then
    echo "Missing ${NV_NODE_DIR}/address" >&2
    return 1
  fi
}

new_validator_write_env() {
  local root="$1"
  local node_id="$2"
  new_validator_compose_paths "${root}" "${node_id}"
  local address
  address="$(tr '[:upper:]' '[:lower:]' < "${NV_NODE_DIR}/address")"
  cat > "${NV_ENV_FILE}" <<EOF
VALIDATOR_ADDRESS=${address}
SPEC_PATH=./genesis/spec.json
OE_CONFIG_PATH=./nodes/${node_id}/config.toml
EOF
  echo "Wrote ${NV_ENV_FILE}"
}

new_validator_write_override() {
  local root="$1"
  local node_id="$2"
  new_validator_compose_paths "${root}" "${node_id}"
  mkdir -p "${root}/overrides" "${NV_NODE_DIR}/data"
  cat > "${NV_OVERRIDE}" <<EOF
services:
  openethereum:
    container_name: 'dpos-\${NETWORK_TYPE:-testnet}-${node_id}'
    env_file:
      - ../chain-dpos/envs/openethereum.env
      - ../chain-dpos/envs/${node_id}.env
    environment:
      OE_CONFIG_PATH: /app/config/config.toml
    volumes: !override
      - ../chain-dpos/genesis/spec.json:/app/genesis/spec.json:ro
      - ../chain-dpos/nodes/${node_id}/config.toml:/app/config/config.toml:ro
      - ../chain-dpos/nodes/${node_id}/reserved-peers.txt:/app/config/reserved-peers.txt:ro
      - ../chain-dpos/nodes/${node_id}/keystore:/app/data/keys/\${NETWORK_NAME}
      - ../chain-dpos/nodes/${node_id}/node.pwd:/app/secrets/node.pwd:ro
      - ../chain-dpos/nodes/${node_id}/data:/app/data
    ports: !override
      - "127.0.0.1:8545:8545"
      - "30300:30300"
      - "30300:30300/udp"
  netstats-api:
    container_name: 'dpos-\${NETWORK_TYPE:-testnet}-netstats-${node_id}'
    depends_on:
      - openethereum
    env_file:
      - ../chain-dpos/envs/netstats-dashboard.env
      - ../chain-dpos/envs/netstats-api.env
    environment:
      INSTANCE_NAME: ${node_id}
      RPC_HOST: openethereum
EOF
  echo "Wrote ${NV_OVERRIDE}"
}

new_validator_write_compose() {
  local root="$1"
  local node_id="$2"
  new_validator_compose_paths "${root}" "${node_id}"
  cat > "${NV_COMPOSE}" <<EOF
name: dpos-${node_id}

include:
  - path:
      - ../services/compose-openethereum-node.yml
      - ../services/compose-netstats-api.yml
      - ./overrides/${node_id}.override.yml
    env_file:
      - ./envs/dpos.chain.env
      - ./envs/images.env
      - ./envs/netstats-dashboard.env
      - ./envs/netstats-api.env
EOF
  echo "Wrote ${NV_COMPOSE}"
}

new_validator_prepare_files() {
  local root="$1"
  local node_id="$2"
  new_validator_require_node "${root}" "${node_id}"
  new_validator_write_env "${root}" "${node_id}"
  new_validator_write_override "${root}" "${node_id}"
  new_validator_write_compose "${root}" "${node_id}"
}
