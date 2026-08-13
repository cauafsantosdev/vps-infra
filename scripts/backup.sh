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

BACKUP_DIR="/var/backups/vps-infra/postgres"
TIMESTAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
FILENAME="postgres-${TIMESTAMP}.sql.gz"
BACKUP_PATH="${BACKUP_DIR}/${FILENAME}"

mkdir -p "$BACKUP_DIR"

echo "Creating PostgreSQL backup..."

docker compose exec -T postgres \
    pg_dumpall \
    -U "$POSTGRES_USER" \
    | gzip -9 > "$BACKUP_PATH"

gzip -t "$BACKUP_PATH"

echo "Backup created:"
echo "$BACKUP_PATH"

if [[ "${R2_BACKUP_ENABLED:-false}" == "true" ]]; then
    : "${R2_ACCOUNT_ID:?R2_ACCOUNT_ID is required}"
    : "${R2_ACCESS_KEY_ID:?R2_ACCESS_KEY_ID is required}"
    : "${R2_SECRET_ACCESS_KEY:?R2_SECRET_ACCESS_KEY is required}"
    : "${R2_BACKUP_BUCKET:?R2_BACKUP_BUCKET is required}"

    export RCLONE_CONFIG_R2_TYPE=s3
    export RCLONE_CONFIG_R2_PROVIDER=Cloudflare
    export RCLONE_CONFIG_R2_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
    export RCLONE_CONFIG_R2_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
    export RCLONE_CONFIG_R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
    export RCLONE_CONFIG_R2_ACL=private

    echo "Uploading backup to Cloudflare R2..."

    rclone copyto \
        "$BACKUP_PATH" \
        "r2:${R2_BACKUP_BUCKET}/postgres/${FILENAME}"

    echo "R2 upload completed."
fi

RETENTION="${BACKUP_RETENTION_DAYS:-7}"

find "$BACKUP_DIR" \
    -type f \
    -name 'postgres-*.sql.gz' \
    -mtime "+$RETENTION" \
    -delete

echo "Backup completed successfully."