# Deployment

Application deployments are intentionally separated from shared infrastructure deployments.

`vps-infra` owns:

- PostgreSQL
- Redis
- Caddy
- Prometheus
- Grafana
- exporters
- host bootstrap
- database backups

Application repositories own their own runtime and deployment.

## Infrastructure deployment

Shared infrastructure lives at:

```text
/opt/vps-infra
```

Deploy or update it with:

```bash
cd /opt/vps-infra
git pull
make deploy
```

`make deploy`:

1. ensures shared Docker networks exist
2. pulls infrastructure images
3. reconciles the shared Compose stack
4. validates Caddy configuration
5. reloads Caddy
6. shows container status

It does not deploy application projects.

## Application deployment

Each project lives independently under:

```text
/opt/apps/<project>
```

Example:

```text
/opt/apps/project-a
```

A typical production deployment is:

```bash
cd /opt/apps/project-a
docker compose pull
docker compose up -d --remove-orphans
```

## GitHub Actions

The intended CI/CD flow is:

```text
push to main
    |
    v
GitHub Actions
    |
    ├── lint
    ├── tests
    ├── Docker build
    |
    v
GitHub Container Registry
    |
    v
SSH to VPS
    |
    ├── docker compose pull
    └── docker compose up -d
```

The VPS should not normally build application Docker images.

Builds should happen on GitHub Actions runners.

## Container registry

Application images should be published to GHCR.

Example:

```text
ghcr.io/<github-user>/project-a-api:<commit-sha>
ghcr.io/<github-user>/project-a-worker:<commit-sha>
```

Using immutable commit SHA tags makes deployments easier to trace and roll back.

A `latest` tag may also be published for convenience, but production deployments should ideally know exactly which image revision they are running.

## Shared infrastructure access

Applications connect to infrastructure through Docker networks.

### PostgreSQL

```text
postgres:5432
```

### Redis

```text
redis:6379
```

### Public routing

Caddy reaches application services through:

```text
vps-edge
```

Applications must not expose internal database or broker ports publicly.

## Celery

Celery belongs to the application repository.

Example project:

```yaml
services:
  api:
    image: ghcr.io/example/project-a:latest

  worker:
    image: ghcr.io/example/project-a:latest
    command: celery -A app.celery worker --loglevel=info --concurrency=1

  beat:
    image: ghcr.io/example/project-a:latest
    command: celery -A app.celery beat --loglevel=info
```

The shared Redis container may be used as the Celery broker.

Heavy workers, especially ML workloads, should start with conservative concurrency.

## Database migrations

Database migrations belong to the application deployment process.

For example:

```text
deploy
  |
  ├── pull image
  ├── run migrations
  └── recreate application containers
```

Migration commands should not live in `vps-infra`.

## Rollbacks

Because application images are stored in GHCR, rollback should consist of deploying a previous image tag.

Example:

```text
current:
ghcr.io/example/project-a:a1b2c3d

rollback:
ghcr.io/example/project-a:9f8e7d6
```

The exact rollback process belongs to each application's repository.

## Separation of responsibilities

The intended boundary is:

```text
vps-infra
    |
    ├── machine
    ├── shared services
    ├── monitoring
    └── backups

application repo
    |
    ├── application
    ├── workers
    ├── migrations
    ├── CI
    └── CD
```

Application deployments must not restart or recreate:

- PostgreSQL
- Redis
- Caddy
- Prometheus
- Grafana

Infrastructure deployments must not redeploy applications.
