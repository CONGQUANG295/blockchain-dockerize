#!/bin/sh
# One-shot init for Postgres bind mounts: db and stats-db run as UID 2000.
# Re-run on every deploy (docker compose run --rm) — compose skips completed
# init containers on `up -d`, so root-owned files from a bad first boot persist.
set -e

DATA="${PGDATA:-/var/lib/postgresql/data}"
mkdir -p "${DATA}"
chown -R 2000:2000 "${DATA}"
chmod 700 "${DATA}"
echo "postgres data permissions set (2000:2000) on ${DATA}"
