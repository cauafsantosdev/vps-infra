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

echo "Checking PostgreSQL..."
docker compose exec -T postgres \
    pg_isready \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB"

echo "Checking Redis..."
docker compose exec -T \
    -e REDISCLI_AUTH="$REDIS_PASSWORD" \
    redis redis-cli ping \
    | grep -q PONG

echo "Checking Caddy..."
curl --fail --silent --show-error \
    http://127.0.0.1/healthz \
    >/dev/null

echo "Checking Prometheus..."
curl --fail --silent --show-error \
    http://127.0.0.1:9090/-/healthy \
    >/dev/null

echo
echo "All infrastructure health checks passed."