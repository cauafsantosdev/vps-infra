# Adding a Project

Applications remain independent from `vps-infra`.

Each project repository owns:

- application containers
- workers
- Celery workers
- Celery Beat, if needed
- migrations
- application-specific configuration
- CI/CD
- deployment

The shared infrastructure repository only provides common services.

## 1. Create a PostgreSQL database

Create a dedicated database and role for the project:

```bash
cd /opt/vps-infra
make db-create NAME=project-a
```

The command generates:

- database name
- PostgreSQL role
- random password

Example output:

```text
Database: project-a
Username: project-a
Password: <generated-password>
```

Store the generated password in the application's production secrets.

Do not store project database passwords in the `vps-infra` repository.

## 2. Connect to shared PostgreSQL

From containers connected to `vps-data`, PostgreSQL is available at:

```text
postgres:5432
```

Example connection string:

```text
postgresql://project-a:<password>@postgres:5432/lexos
```

Each application should use its own database and PostgreSQL role.

## 3. Connect to shared Redis

Redis is available to containers connected to `vps-data` at:

```text
redis:6379
```

Use project-specific:

- Redis logical databases
- key prefixes
- Celery queues

For example:

```dotenv
CELERY_BROKER_URL=redis://:password@redis:6379/1
CELERY_RESULT_BACKEND=redis://:password@redis:6379/2
```

Avoid using the same default Celery queue across unrelated projects.

Prefer queue names such as:

```text
project-a.default
project-a.dedicated-feat-queue
project-b.default
```

## 4. Join shared Docker networks

A public API will typically join both `vps-edge` and `vps-data`.

Example:

```yaml
services:
  api:
    image: ghcr.io/example/project:latest
    restart: unless-stopped

    networks:
      edge:
        aliases:
          - project-a-api
      data:

networks:
  edge:
    external: true
    name: vps-edge

  data:
    external: true
    name: vps-data
```

The network alias should be unique across the VPS.

For example:

```text
project-a-api
project-b-api
project-c-api
```

## 5. Expose Prometheus metrics

If the application exposes a `/metrics` endpoint, it can also join:

```yaml
networks:
  monitoring:
    external: true
    name: vps-monitoring
```

Example:

```yaml
services:
  api:
    networks:
      - edge
      - data
      - monitoring

networks:
  edge:
    external: true
    name: vps-edge

  data:
    external: true
    name: vps-data

  monitoring:
    external: true
    name: vps-monitoring
```

Prometheus scraping configuration can then be added to:

```text
prometheus/prometheus.yml
```

## 6. Configure Caddy

Create a Caddy configuration for the project under:

```text
caddy/sites/
```

Example:

```text
caddy/sites/project-a.caddy
```

Contents:

```caddyfile
lexos.example.com {
    reverse_proxy project-a-api:8000
}
```

Caddy reaches the application through `vps-edge`.

After modifying Caddy configuration:

```bash
cd /opt/vps-infra
make deploy
```

Caddy handles HTTPS automatically when:

- the domain resolves to the VPS
- ports 80 and 443 are reachable

## 7. Object storage

Production object storage uses Cloudflare R2.

Applications should use generic S3-compatible configuration:

```dotenv
S3_ENDPOINT=
S3_ACCESS_KEY_ID=
S3_SECRET_ACCESS_KEY=
S3_BUCKET=
S3_REGION=
```

Object-storage credentials belong to the application, not the shared infrastructure repository.

For local development, an S3-compatible service such as SeaweedFS may be used instead.

## 8. Application deployment

Applications should be deployed independently through GitHub Actions.

Typical flow:

```text
push to main
    |
    v
GitHub Actions
    |
    ├── tests
    ├── Docker build
    └── push image to GHCR
             |
             v
          VPS SSH
             |
             ├── docker compose pull
             └── docker compose up -d
```

Application deployments must not recreate or restart shared infrastructure services.
