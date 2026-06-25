#!/usr/bin/env bash
# Operator machine: rsync minimal bundle for a new validator (non-seed) to remote server.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ssh-common.sh
source "${SCRIPT_DIR}/ssh-common.sh"

ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_DIR="$(cd "${ROOT_DIR}/.." && pwd)"
SERVICES_DIR="${COMPOSE_DIR}/services"

REMOTE=""
REMOTE_DIR="${REMOTE_DIR:-${BLOCKCHAIN_DOCK_ROOT:-/opt/blockchain-dock}}"
NODE_ID="${NODE_ID:-}"
DRY_RUN=false
PRUNE_REMOTE=true

usage() {
  cat <<'EOF'
Usage: ./scripts/local/sync-new-validator.sh user@host [remote_dir] [options]

Sync only what a new validator needs on the remote server:

  chain-dpos/genesis/, nodes/<NODE_ID>/, scripts/, templates/
  chain-dpos/overrides/<NODE_ID>.override.yml, compose-<NODE_ID>.yml (if present)
  chain-dpos/envs/ (whitelist only)
  docker-compose/envs/ (netstats only — paths in services/*.yml)
  services/: compose-openethereum-node.yml, compose-netstats-api.yml

Does NOT sync: Makefile, make/, DApps compose, traefik, assets, seed validator-1.
Prune removes stale files from prior full syncs on the remote host.

Options:
  --node-id ID     Validator node directory name (required), e.g. validator-2
  --no-prune       Do not remove stale DApps files from prior full syncs
  --dry-run        Print rsync commands without syncing
  -h, --help

Makefile:
  make sync-new-validator SERVER=user@host NODE_ID=validator-N [REMOTE_DIR=...]
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --node-id) NODE_ID="${2:?}"; shift 2 ;;
    --no-prune) PRUNE_REMOTE=false; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [ -z "${REMOTE}" ]; then
        REMOTE="$1"
      elif [[ "$1" != *@* ]]; then
        REMOTE_DIR="$1"
      else
        echo "Unexpected argument: $1" >&2
        usage
        exit 1
      fi
      shift
      ;;
  esac
done

if [ -z "${REMOTE}" ]; then
  usage
  exit 1
fi

if [ -z "${NODE_ID}" ]; then
  echo "NODE_ID is required (e.g. validator-2)." >&2
  echo "Run: make prepare-new-validator-local SEED_SERVER=... [NODE_ID=validator-N]" >&2
  usage
  exit 1
fi

if [ ! -d "${ROOT_DIR}/nodes/${NODE_ID}" ]; then
  echo "Missing nodes/${NODE_ID} — run: make prepare-new-validator-local SEED_SERVER=... NODE_ID=${NODE_ID}" >&2
  exit 1
fi

if [ ! -f "${ROOT_DIR}/genesis/spec.json" ]; then
  echo "Missing genesis/spec.json — run pull-peer-config first." >&2
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync required on operator machine." >&2
  exit 1
fi

REMOTE_CHAIN="${REMOTE_DIR}/blockchain-dockerize/docker-compose/chain-dpos"
REMOTE_SERVICES="${REMOTE_DIR}/blockchain-dockerize/docker-compose/services"
REMOTE_CHAIN_ENVS="${REMOTE_CHAIN}/envs"
REMOTE_COMPOSE_ENVS="${REMOTE_DIR}/blockchain-dockerize/docker-compose/envs"
DEPLOY_USER="${REMOTE%%@*}"

REQUIRED_ENVS=(
  deploy.env
  dpos.chain.env
  images.env
  openethereum.env
  netstats-api.env
  netstats-dashboard.env
)

# services/compose-netstats-api.yml references ../envs/*.env (compose dir, not chain-dpos)
COMPOSE_ENVS=(
  netstats-api.env
  netstats-dashboard.env
)

REQUIRED_SERVICES=(
  compose-openethereum-node.yml
  compose-netstats-api.yml
)

missing_env=()
for f in "${REQUIRED_ENVS[@]}"; do
  if [ ! -f "${ROOT_DIR}/envs/${f}" ]; then
    missing_env+=("${f}")
  fi
done
if [ ${#missing_env[@]} -gt 0 ]; then
  echo "Missing chain-dpos/envs on operator machine: ${missing_env[*]}" >&2
  echo "Run: make render   (after editing envs/deploy.env)" >&2
  if [ ! -f "${ROOT_DIR}/envs/deploy.env" ] && [ -f "${ROOT_DIR}/envs/deploy.env.example" ]; then
    echo "Or: cp envs/deploy.env.example envs/deploy.env && edit DOCKERHUB_NAMESPACE, NETWORK_*, P2P_PUBLIC_IP" >&2
  fi
  exit 1
fi

RSYNC_OPTS=(-avz)

run_rsync() {
  local src="$1"
  local dest="$2"
  shift 2
  local -a extra=("$@")
  if [ "${DRY_RUN}" = true ]; then
    echo "rsync ${RSYNC_OPTS[*]} ${extra[*]} ${src} ${dest}"
  else
    rsync "${RSYNC_OPTS[@]}" "${extra[@]}" "${src}" "${dest}"
  fi
}

if [ "${DRY_RUN}" = false ]; then
  require_ssh_key_auth "${REMOTE}"
  init_ssh_mux "${REMOTE}"
  trap close_ssh_mux EXIT
fi

echo "Target: ${REMOTE}:${REMOTE_CHAIN} (new validator: ${NODE_ID}, minimal bundle)"

if [ "${DRY_RUN}" = true ]; then
  echo "ssh ${REMOTE} sudo mkdir -p ... && chown ${DEPLOY_USER}"
else
  ssh_cmd "${REMOTE}" "sudo mkdir -p \
    '${REMOTE_CHAIN}' '${REMOTE_CHAIN}/envs' '${REMOTE_CHAIN}/genesis' \
    '${REMOTE_CHAIN}/nodes/${NODE_ID}' '${REMOTE_CHAIN}/scripts' '${REMOTE_CHAIN}/templates' \
    '${REMOTE_CHAIN}/overrides' '${REMOTE_SERVICES}' '${REMOTE_COMPOSE_ENVS}' && \
    sudo chown -R '${DEPLOY_USER}:${DEPLOY_USER}' '${REMOTE_DIR}'"
fi

# --- services: only openethereum + netstats-api ---
for svc in "${REQUIRED_SERVICES[@]}"; do
  if [ ! -f "${SERVICES_DIR}/${svc}" ]; then
    echo "Missing ${SERVICES_DIR}/${svc}" >&2
    exit 1
  fi
  run_rsync "${SERVICES_DIR}/${svc}" "${REMOTE}:${REMOTE_SERVICES}/${svc}"
done

# --- chain-dpos envs: whitelist only (drop stale DApps env files on remote) ---
ENV_RSYNC_OPTS=(-avz --delete --delete-excluded)
ENV_INCLUDES=(
  --include 'deploy.env'
  --include 'dpos.chain.env'
  --include 'images.env'
  --include 'openethereum.env'
  --include 'netstats-api.env'
  --include 'netstats-dashboard.env'
  --include "${NODE_ID}.env"
  --exclude '*'
)
if [ "${DRY_RUN}" = true ]; then
  echo "rsync ${ENV_RSYNC_OPTS[*]} ${ENV_INCLUDES[*]} ${ROOT_DIR}/envs/ ${REMOTE}:${REMOTE_CHAIN_ENVS}/"
else
  rsync "${ENV_RSYNC_OPTS[@]}" "${ENV_INCLUDES[@]}" "${ROOT_DIR}/envs/" "${REMOTE}:${REMOTE_CHAIN_ENVS}/"
fi

# --- compose/envs: ../envs/*.env paths from services/compose-netstats-api.yml ---
COMPOSE_ENV_RSYNC_OPTS=(-avz --delete --delete-excluded)
COMPOSE_ENV_INCLUDES=(--exclude '*')
for f in "${COMPOSE_ENVS[@]}"; do
  COMPOSE_ENV_INCLUDES=(--include "${f}" "${COMPOSE_ENV_INCLUDES[@]}")
done
if [ "${DRY_RUN}" = true ]; then
  echo "rsync ${COMPOSE_ENV_RSYNC_OPTS[*]} ${COMPOSE_ENV_INCLUDES[*]} ${ROOT_DIR}/envs/ ${REMOTE}:${REMOTE_COMPOSE_ENVS}/"
else
  rsync "${COMPOSE_ENV_RSYNC_OPTS[@]}" "${COMPOSE_ENV_INCLUDES[@]}" \
    "${ROOT_DIR}/envs/" "${REMOTE}:${REMOTE_COMPOSE_ENVS}/"
fi

# --- chain-dpos core (no full nodes/ or envs/) ---
run_rsync "${ROOT_DIR}/genesis/" "${REMOTE}:${REMOTE_CHAIN}/genesis/"
run_rsync "${ROOT_DIR}/nodes/${NODE_ID}/" "${REMOTE}:${REMOTE_CHAIN}/nodes/${NODE_ID}/"
run_rsync "${ROOT_DIR}/scripts/" "${REMOTE}:${REMOTE_CHAIN}/scripts/"
run_rsync "${ROOT_DIR}/templates/" "${REMOTE}:${REMOTE_CHAIN}/templates/"
if [ -f "${ROOT_DIR}/overrides/${NODE_ID}.override.yml" ]; then
  run_rsync "${ROOT_DIR}/overrides/${NODE_ID}.override.yml" \
    "${REMOTE}:${REMOTE_CHAIN}/overrides/${NODE_ID}.override.yml"
fi
if [ -f "${ROOT_DIR}/compose-${NODE_ID}.yml" ]; then
  run_rsync "${ROOT_DIR}/compose-${NODE_ID}.yml" "${REMOTE}:${REMOTE_CHAIN}/compose-${NODE_ID}.yml"
fi

KEEP_CHAIN_ENVS=(
  deploy.env
  dpos.chain.env
  images.env
  openethereum.env
  netstats-api.env
  netstats-dashboard.env
  "${NODE_ID}.env"
)
KEEP_CHAIN_ENVS_CSV="$(IFS=,; echo "${KEEP_CHAIN_ENVS[*]}")"

# No full chain-dpos/ rsync — explicit paths only (avoids DApps Makefile, compose-dapps, etc.)
if [ "${PRUNE_REMOTE}" = true ]; then
  prune_script="$(cat <<'PRUNE'
set -e
services_dir="$1"
compose_envs_dir="$2"
chain_dir="$3"
node_id="$4"
keep_svc="$5"
keep_svc2="$6"
chain_envs_dir="$7"
keep_chain_envs="$8"
if [ -d "${services_dir}" ]; then
  find "${services_dir}" -mindepth 1 -maxdepth 1 ! -name "${keep_svc}" ! -name "${keep_svc2}" -exec rm -rf {} +
fi
if [ -d "${compose_envs_dir}" ]; then
  find "${compose_envs_dir}" -mindepth 1 -maxdepth 1 \
    ! -name 'netstats-api.env' ! -name 'netstats-dashboard.env' -exec rm -rf {} +
fi
if [ -d "${chain_envs_dir}" ]; then
  for env_file in "${chain_envs_dir}"/*; do
    [ -e "${env_file}" ] || continue
    base="$(basename "${env_file}")"
    case ",${keep_chain_envs}," in
      *,"${base}",*) ;;
      *) rm -f "${env_file}" ;;
    esac
  done
fi
if [ -d "${chain_dir}" ]; then
  rm -f "${chain_dir}/Makefile" 2>/dev/null || true
  rm -rf "${chain_dir}/make" "${chain_dir}/examples" "${chain_dir}/assets" \
    "${chain_dir}/traefik" "${chain_dir}/data" 2>/dev/null || true
  for compose_file in "${chain_dir}"/compose-*.yml; do
    [ -e "${compose_file}" ] || continue
    base="$(basename "${compose_file}")"
    if [ "${base}" != "compose-${node_id}.yml" ]; then
      rm -f "${compose_file}"
    fi
  done
  if [ -d "${chain_dir}/overrides" ]; then
    find "${chain_dir}/overrides" -mindepth 1 -maxdepth 1 \
      ! -name "${node_id}.override.yml" -exec rm -rf {} +
  fi
  if [ -d "${chain_dir}/nodes" ]; then
    find "${chain_dir}/nodes" -mindepth 1 -maxdepth 1 ! -name "${node_id}" -exec rm -rf {} +
  fi
fi
PRUNE
)"
  if [ "${DRY_RUN}" = true ]; then
    echo "ssh prune: services/* except ${REQUIRED_SERVICES[*]}; trim envs/; trim chain-dpos DApps artifacts"
  else
    ssh_cmd "${REMOTE}" "bash -s" -- "${REMOTE_SERVICES}" "${REMOTE_COMPOSE_ENVS}" "${REMOTE_CHAIN}" "${NODE_ID}" \
      "${REQUIRED_SERVICES[0]}" "${REQUIRED_SERVICES[1]}" "${REMOTE_CHAIN_ENVS}" "${KEEP_CHAIN_ENVS_CSV}" <<< "${prune_script}"
  fi
fi

if [ "${DRY_RUN}" = false ]; then
  ssh_cmd "${REMOTE}" "chmod +x '${REMOTE_CHAIN}/scripts/'*.sh '${REMOTE_CHAIN}/scripts/remote/'*.sh 2>/dev/null || true"
fi

echo ""
echo "Sync complete (minimal) for ${NODE_ID}."
echo "  chain-dpos/: genesis/ envs/ nodes/${NODE_ID}/ scripts/ templates/ overrides/ compose-${NODE_ID}.yml"
echo "  services/: ${REQUIRED_SERVICES[*]}"
echo "  compose/envs/: ${COMPOSE_ENVS[*]}"
if [ "${PRUNE_REMOTE}" = true ]; then
  echo "  pruned:   DApps artifacts (Makefile, compose-dapps*, traefik, assets, …)"
fi
echo ""
echo "Start:"
echo "  make ssh-new-validator-up SERVER=${REMOTE} NODE_ID=${NODE_ID} REMOTE_DIR=${REMOTE_DIR}"
