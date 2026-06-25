#!/usr/bin/env bash
# Open P2P port (default 30300 TCP/UDP) via ufw for cross-server validator peering.
# shellcheck shell=bash

open_p2p_firewall() {
  local port="${P2P_PORT:-30300}"

  if [ "${OPEN_P2P_PORT:-}" != "1" ] && [ "${OPEN_P2P_PORT:-}" != "true" ]; then
    echo "OPEN_P2P_PORT not set — skip P2P firewall (set OPEN_P2P_PORT=1 to enable)" >&2
    return 0
  fi

  if ! command -v ufw >/dev/null 2>&1; then
    if [ "$(id -u)" -eq 0 ]; then
      echo "Installing ufw..."
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -qq
      apt-get install -y -qq ufw
    else
      echo "ufw not found — install ufw or open port ${port} TCP/UDP in cloud security group." >&2
      return 1
    fi
  fi

  ensure_ssh_allowed

  # Idempotent; does not enable ufw if it was inactive.
  ufw allow "${port}/tcp" comment 'OpenEthereum P2P' >/dev/null
  ufw allow "${port}/udp" comment 'OpenEthereum P2P' >/dev/null

  if ufw status 2>/dev/null | grep -q "Status: active"; then
    echo "UFW active: SSH + ${port}/tcp + ${port}/udp allowed"
  else
    echo "UFW rules added: SSH + ${port}/tcp + ${port}/udp (UFW inactive — rules apply when enabled)"
    echo "UFW is not auto-enabled — run 'sudo ufw enable' only after verifying SSH rule."
    echo "Also open ${port} TCP/UDP in cloud security group if nodes are on other hosts."
  fi
}

ensure_ssh_allowed() {
  local ssh_port="${SSH_PORT:-}"

  if [ -z "${ssh_port}" ] && [ -f /etc/ssh/sshd_config ]; then
    ssh_port="$(grep -E '^[[:space:]]*Port[[:space:]]+' /etc/ssh/sshd_config 2>/dev/null \
      | awk '{print $2}' | tail -1 || true)"
  fi
  ssh_port="${ssh_port:-22}"

  if ufw status 2>/dev/null | grep -qE "(^|[[:space:]])${ssh_port}/tcp|OpenSSH"; then
    echo "UFW: SSH port ${ssh_port}/tcp already allowed"
    return 0
  fi

  # Prefer OpenSSH profile on Ubuntu when using default port 22.
  if [ "${ssh_port}" = "22" ] && ufw app list 2>/dev/null | grep -q OpenSSH; then
    ufw allow OpenSSH comment 'SSH' >/dev/null
    echo "UFW: allowed OpenSSH (port 22/tcp)"
  else
    ufw allow "${ssh_port}/tcp" comment 'SSH' >/dev/null
    echo "UFW: allowed ${ssh_port}/tcp (SSH)"
  fi
}

resolve_p2p_public_ip() {
  if [ -n "${P2P_PUBLIC_IP:-}" ]; then
    echo "${P2P_PUBLIC_IP}"
    return 0
  fi

  local detected=""
  for url in \
    "https://api.ipify.org" \
    "https://ifconfig.me/ip" \
    "https://icanhazip.com"
  do
    detected="$(curl -sf --max-time 5 "${url}" 2>/dev/null | tr -d '[:space:]' || true)"
    if [ -n "${detected}" ]; then
      echo "${detected}"
      return 0
    fi
  done

  return 1
}

rewrite_enode_public_ip() {
  local enode="$1"
  local public_ip="$2"

  if [ -z "${enode}" ] || [ -z "${public_ip}" ]; then
    echo "${enode}"
    return 0
  fi

  # enode://<pubkey>@<host>:<port>
  echo "${enode}" | sed -E "s|(@)[^:]+(:)|\1${public_ip}\2|"
}
