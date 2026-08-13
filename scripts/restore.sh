#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
    echo "error: .env does not exist"
    exit 1
fi

set -a
source .env
set +a

BACKUP="${1:-}"

if [[ -z "$BACKUP" ]]; then
    echo "usage: $0 <postgres-backup.sql.gz>"
    exit 1
fi

if [[ ! -f "$BACKUP" ]]; then
    echo "error: backup file not found: $BACKUP"
    exit 1
fi

gzip -t "$BACKUP"

echo "WARNING:"
echo "This restores all databases and roles contained in the backup."
echo "It is intended primarily for disaster recovery onto a fresh PostgreSQL instance."
echo

gzip -dc "$BACKUP" \
    | docker compose exec -T postgres \
        psql \
        -U "$POSTGRES_USER" \
        -d "$POSTGRES_DB"

echo
echo "Restore completed."