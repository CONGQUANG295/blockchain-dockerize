# shellcheck shell=bash
# Shared peer bundle paths and helpers (source from scripts).

peer_config_paths() {
  local root="${1:?chain-dpos root required}"
  # shellcheck source=paths.sh
  source "${root}/scripts/lib/paths.sh"
  chain_dpos_paths "${root}"
  PATH_PEERS_DIR="${PATH_GENESIS}/peers"
  PATH_GENESIS_RESERVED_PEERS="${PATH_GENESIS}/reserved-peers.txt"
}

peer_config_ensure_dirs() {
  mkdir -p "${PATH_PEERS_DIR}" "${PATH_NODE_RPC}" "${PATH_NODE_VALIDATOR}"
}

peer_config_normalize_enode() {
  tr -d '[:space:]' < "$1"
}

peer_config_append_reserved_peer() {
  local enode="$1"
  local file="$2"
  local existing line

  [ -n "${enode}" ] || return 1
  touch "${file}"
  while IFS= read -r line || [ -n "${line}" ]; do
    line="$(echo "${line}" | tr -d '[:space:]')"
    [ -n "${line}" ] || continue
    if [ "${line}" = "${enode}" ]; then
      return 0
    fi
  done < "${file}"
  printf '%s\n' "${enode}" >> "${file}"
}

peer_config_sync_reserved_peers() {
  local root="${1:?chain-dpos root required}"
  peer_config_paths "${root}"
  peer_config_ensure_dirs

  if [ ! -f "${PATH_GENESIS_RESERVED_PEERS}" ]; then
    echo "Missing ${PATH_GENESIS_RESERVED_PEERS}" >&2
    return 1
  fi

  local target
  for target in \
    "${PATH_RESERVED_PEERS}" \
    "${PATH_NODE_VALIDATOR}/reserved-peers.txt"
  do
    mkdir -p "$(dirname "${target}")"
    cp "${PATH_GENESIS_RESERVED_PEERS}" "${target}"
    echo "Synced reserved-peers → ${target}"
  done
}

peer_config_list_bundle_files() {
  local root="${1:?chain-dpos root required}"
  peer_config_paths "${root}"
  local -a files=(
    "${PATH_SPEC}"
    "${PATH_GENESIS_RESERVED_PEERS}"
    "${PATH_VALIDATOR_ENODE}"
  )
  if [ -f "${PATH_CONTRACT_ADDRESSES}" ]; then
    files+=("${PATH_CONTRACT_ADDRESSES}")
  fi
  if [ -d "${PATH_PEERS_DIR}" ]; then
    while IFS= read -r -d '' f; do
      files+=("${f}")
    done < <(find "${PATH_PEERS_DIR}" -maxdepth 1 -name '*.enode' -print0 2>/dev/null || true)
  fi
  printf '%s\n' "${files[@]}"
}
