#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."

docker compose pull
docker compose up -d --remove-orphans

echo "Validating Caddy configuration..."
docker compose exec -T caddy \
    caddy validate --config /etc/caddy/Caddyfile

echo "Reloading Caddy..."
docker compose exec -T caddy \
    caddy reload --config /etc/caddy/Caddyfile

echo
docker compose ps