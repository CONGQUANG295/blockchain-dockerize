# shellcheck shell=bash
# Standard docker compose env for ${IMAGE} substitution in compose YAML.

chain_dpos_compose_env() {
  local root="${1:?chain-dpos root required}"
  COMPOSE_ENV_FILES=(
    --env-file "${root}/envs/images.env"
    --env-file "${root}/envs/dpos.chain.env"
  )
}

chain_dpos_compose() {
  local root="${1:?chain-dpos root required}"
  shift
  chain_dpos_compose_env "${root}"
  docker compose "${COMPOSE_ENV_FILES[@]}" "$@"
}
