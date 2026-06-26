#!/usr/bin/env bash
# Shared helpers for server-side remote deploy scripts.
# shellcheck shell=bash

remote_chain_dpos_root() {
  if [ -n "${CHAIN_DPOS_ROOT:-}" ] && [ -d "${CHAIN_DPOS_ROOT}" ]; then
    echo "${CHAIN_DPOS_ROOT}"
    return 0
  fi

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  if [ -f "${script_dir}/../../compose-validator-1.yml" ]; then
    cd "${script_dir}/../.." && pwd
    return 0
  fi

  local default="/opt/blockchain-dock/blockchain-dockerize/docker-compose/chain-dpos"
  if [ -d "${default}" ]; then
    echo "${default}"
    return 0
  fi

  echo "Cannot find chain-dpos root. Set CHAIN_DPOS_ROOT." >&2
  return 1
}

remote_dock_root() {
  local chain_root
  chain_root="$(remote_chain_dpos_root)" || return 1
  cd "${chain_root}/../../.." && pwd
}

remote_require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing required command: ${cmd}. Run scripts/remote/provision-server.sh first." >&2
    return 1
  fi
}

remote_require_docker() {
  remote_require_cmd docker || return 1
  if ! docker compose version >/dev/null 2>&1; then
    echo "Docker Compose v2 plugin required (docker compose)." >&2
    return 1
  fi
}

remote_require_deploy_env() {
  local root="$1"
  if [ ! -f "${root}/envs/deploy.env" ]; then
    echo "Missing ${root}/envs/deploy.env — prepare locally and sync to server." >&2
    return 1
  fi

  set -a
  # shellcheck disable=SC1090
  source "${root}/envs/deploy.env"
  set +a

  if [ -z "${DOCKERHUB_NAMESPACE:-}" ]; then
    echo "DOCKERHUB_NAMESPACE must be set in envs/deploy.env for remote Docker Hub deploy." >&2
    return 1
  fi
}

remote_wait_for_rpc() {
  # shellcheck source=../wait-for-rpc.sh
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/wait-for-rpc.sh"
  wait_for_rpc "$@"
}

# db/stats-db run as UID 2000; bind-mount data may be root-owned after a bad first boot.
# `docker compose up` skips one-shot init containers that already exited — run explicitly.
remote_ensure_postgres_data_permissions() {
  local -a compose_args=("$@")
  echo "=== Ensure Postgres data dir ownership (UID 2000) ==="
  docker compose "${compose_args[@]}" run --rm --no-deps db-init
  docker compose "${compose_args[@]}" run --rm --no-deps stats-db-init
}
