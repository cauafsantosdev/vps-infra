# vps-infra

Shared infrastructure for a single VPS running multiple personal and portfolio projects.

## Responsibilities

This repository owns shared VPS infrastructure:

- Caddy
- PostgreSQL
- Redis
- Prometheus
- Grafana
- host/container/database monitoring
- PostgreSQL backups
- Debian host bootstrap

Application services are owned and deployed independently by their respective repositories.

Production object storage is external and uses Cloudflare R2.

## Architecture

Applications connect to shared infrastructure using external Docker networks:

- `vps-edge`: reverse proxy and HTTP-facing application services
- `vps-data`: PostgreSQL and Redis access
- `vps-monitoring`: Prometheus metrics

Application deployments are handled independently through GitHub Actions.