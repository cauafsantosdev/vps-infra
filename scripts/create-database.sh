#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
    echo "error: .env does not exist"
    exit 1
fi

set -a
source .env
set +a

NAME="${1:-}"

if [[ -z "$NAME" ]]; then
    echo "usage: $0 <database-name>"
    exit 1
fi

if [[ ! "$NAME" =~ ^[a-z][a-z0-9_]*$ ]]; then
    echo "error: database name must match ^[a-z][a-z0-9_]*$"
    exit 1
fi

ROLE_EXISTS="$(
    docker compose exec -T postgres \
        psql \
        -U "$POSTGRES_USER" \
        -d "$POSTGRES_DB" \
        -Atqc "SELECT 1 FROM pg_roles WHERE rolname = '$NAME';"
)"

DB_EXISTS="$(
    docker compose exec -T postgres \
        psql \
        -U "$POSTGRES_USER" \
        -d "$POSTGRES_DB" \
        -Atqc "SELECT 1 FROM pg_database WHERE datname = '$NAME';"
)"

if [[ -n "$ROLE_EXISTS" || -n "$DB_EXISTS" ]]; then
    echo "error: database or role '$NAME' already exists"
    exit 1
fi

PASSWORD="$(openssl rand -hex 32)"

docker compose exec -T postgres \
    psql \
    -v ON_ERROR_STOP=1 \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" <<SQL
CREATE ROLE "$NAME"
    LOGIN
    PASSWORD '$PASSWORD';

CREATE DATABASE "$NAME"
    OWNER "$NAME";
SQL

echo
echo "Database created."
echo
echo "Database: $NAME"
echo "Username: $NAME"
echo "Password: $PASSWORD"
echo
echo "Docker connection:"
echo "postgresql://$NAME:$PASSWORD@postgres:5432/$NAME"
echo
echo "Store this password in the application's secrets."
echo "It is not stored by vps-infra."