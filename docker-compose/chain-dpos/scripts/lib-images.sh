#!/usr/bin/env bash
# Resolve Docker image reference: explicit override > Docker Hub > local tag.
# Usage: resolve_image <explicit> <hub-name> <version> <local-name>
resolve_image() {
  local explicit="${1:-}"
  local hub_name="$2"
  local version="$3"
  local local_name="$4"

  if [ -n "${explicit}" ]; then
    echo "${explicit}"
  elif [ -n "${DOCKERHUB_NAMESPACE:-}" ]; then
    echo "${DOCKERHUB_NAMESPACE}/blockchain-dock-${hub_name}:${version}"
  else
    echo "${local_name}:${version}"
  fi
}
