# vps-infra

Shared infrastructure for a single VPS hosting multiple personal and portfolio projects.

The goal of this repository is to keep the VPS reproducible, lightweight, and easy to operate without turning a single server into an over-engineered platform.

## Responsibilities

`vps-infra` owns shared infrastructure:

* Caddy
* PostgreSQL
* Redis
* Prometheus
* Grafana
* Node Exporter
* cAdvisor
* PostgreSQL Exporter
* PostgreSQL backups
* Debian host bootstrap
* shared Docker networks

Application repositories remain independent and own:

* application containers
* frontends and APIs
* workers
* Celery workers
* Celery Beat
* database migrations
* application-specific configuration
* CI/CD
* deployment

Production S3-compatible object storage is provided externally through Cloudflare R2.

## Architecture

```text
                           Internet
                              |
                           80 / 443
                              |
                              v
                           Caddy
                              |
                         vps-edge
                              |
             +----------------+----------------+
             |                |                |
             v                v                v
          Lexos           NexdWatch         Project N
             |                |                |
             +----------------+----------------+
                              |
                           vps-data
                         /          \
                        v            v
                   PostgreSQL      Redis


                       Observability

Node Exporter ---------+
                       |
cAdvisor --------------+----> Prometheus ----> Grafana
                       |
PostgreSQL Exporter ---+
                       |
Application /metrics --+
```

## Stack

### Core

* **Caddy** — reverse proxy and automatic HTTPS
* **PostgreSQL** — shared database server with one database and role per project
* **Redis** — shared cache, broker, transient state, and Celery infrastructure

### Observability

* **Prometheus** — metrics collection and time-series storage
* **Grafana** — dashboards and visualization
* **Node Exporter** — host CPU, memory, filesystem, network, and kernel metrics
* **cAdvisor** — Docker container resource metrics
* **PostgreSQL Exporter** — PostgreSQL metrics

### External services

* **Cloudflare R2** — production S3-compatible object storage and off-server PostgreSQL backup storage

Object storage is intentionally not hosted on the VPS.

For local development, projects may use an S3-compatible service such as RustFS.

## Repository Structure

```text
vps-infra/
├── .github/
│   └── workflows/
│       └── ci.yml
│
├── caddy/
│   ├── Caddyfile
│   └── sites/
│       └── placeholder.caddy
│
├── docs/
│   ├── ADDING-A-PROJECT.md
│   ├── BACKUPS.md
│   ├── DEPLOYMENT.md
│   ├── OBSERVABILITY.md
│   └── SETUP.md
│
├── grafana/
│   ├── dashboards/
│   │   └── vps-overview.json
│   └── provisioning/
│       ├── dashboards/
│       └── datasources/
│
├── prometheus/
│   ├── prometheus.yml
│   └── rules/
│
├── redis/
│   └── redis.conf
│
├── scripts/
│   ├── backup.sh
│   ├── bootstrap.sh
│   ├── create-database.sh
│   ├── deploy.sh
│   ├── health.sh
│   ├── install-systemd.sh
│   └── restore.sh
│
├── systemd/
│   ├── postgres-backup.service
│   └── postgres-backup.timer
│
├── .env.example
├── .gitignore
├── compose.yml
├── Makefile
└── README.md
```

## Shared Docker Networks

The infrastructure uses three external Docker networks.

### `vps-edge`

Used for HTTP traffic between Caddy and application services.

```text
Internet
   |
   v
 Caddy
   |
vps-edge
   |
   v
Application API
```

Applications that need to receive traffic through Caddy should join this network.

### `vps-data`

Used for access to shared stateful services:

* PostgreSQL
* Redis

Applications should never expose PostgreSQL or Redis directly through host ports.

From containers connected to `vps-data`:

```text
PostgreSQL: postgres:5432
Redis:      redis:6379
```

### `vps-monitoring`

Used by:

* Prometheus
* exporters
* applications exposing `/metrics`

Application containers may join this network when Prometheus needs to scrape them.

## Environment Configuration

Create the local or production environment file:

```bash
cp .env.example .env
chmod 600 .env
```

Never commit `.env`.

## Commands

Show available commands:

```bash
make help
```

Validate Compose configuration:

```bash
make config
```

Create shared Docker networks:

```bash
make networks
```

Start infrastructure:

```bash
make up
```

Stop infrastructure:

```bash
make down
```

Pull new infrastructure images:

```bash
make pull
```

Deploy or reconcile the shared infrastructure:

```bash
make deploy
```

Show container status:

```bash
make status
```

Follow logs:

```bash
make logs
```

Run health checks:

```bash
make health
```

Create a project database:

```bash
make db-create NAME=lexos
```

Create a PostgreSQL backup:

```bash
make backup
```

Restore a PostgreSQL backup:

```bash
make restore FILE=/path/to/postgres-backup.sql.gz
```

Install systemd timers:

```bash
make install-timers
```

## PostgreSQL

A single PostgreSQL server is shared across projects.

Each project receives:

* its own database
* its own PostgreSQL role
* its own password

Example:

```bash
make db-create NAME=project-a
```

This may create:

```text
Database: project-a
Username: project-a
Password: <generated-password>
```

The application then connects through:

```text
postgresql://project-a:<password>@postgres:5432/project-a
```

Project database credentials belong to the application's production secrets.

## Redis

Redis is shared between projects.

Typical uses include:

* caching
* Celery broker
* Celery result backend
* short-lived application state
* distributed locks
* background task coordination

Projects should isolate usage with:

* Redis logical databases
* key prefixes
* project-specific Celery queues

Example:

```dotenv
CELERY_BROKER_URL=redis://:password@redis:6379/1
CELERY_RESULT_BACKEND=redis://:password@redis:6379/2
```

Celery workers themselves are not shared infrastructure and remain inside their respective application repositories.

## Caddy

Caddy is the only public entry point for application HTTP traffic.

Public ports:

```text
80/tcp
443/tcp
443/udp
```

Application-specific routing lives under:

```text
caddy/sites/
```

Example:

```caddyfile
lexos.example.com {
    reverse_proxy project-a-api:8000
}
```

Caddy reaches application containers through `vps-edge`.

When DNS correctly points a domain to the VPS, Caddy automatically manages HTTPS certificates.

## Observability

The monitoring stack provides visibility into the VPS and its applications.

### Prometheus

Collects metrics every 30 seconds.

Current retention limits:

```text
15 days
2 GB maximum TSDB size
```

Prometheus is bound only to:

```text
127.0.0.1:9090
```

### Grafana

Provides dashboards backed by Prometheus.

Grafana is initially bound only to:

```text
127.0.0.1:3000
```

Access it through SSH forwarding:

```bash
ssh -L 3000:127.0.0.1:3000 deploy@SERVER
```

Then open:

```text
http://localhost:3000
```

### Exporters

Node Exporter provides host metrics.

cAdvisor provides container metrics.

PostgreSQL Exporter provides database metrics.

Applications may expose their own `/metrics` endpoints and join `vps-monitoring`.

## Backups

PostgreSQL backups run weekly.

Current schedule:

```text
Sunday at 03:00
```

The systemd timer uses:

```ini
OnCalendar=Sun *-*-* 03:00:00
Persistent=true
```

Local backups are stored under:

```text
/var/backups/vps-infra/postgres/
```

Production backups should also be uploaded to Cloudflare R2.

The off-server copy protects against:

* VPS deletion
* disk failure
* filesystem corruption
* destructive administrative mistakes
* provider-level incidents

See:

```text
docs/BACKUPS.md
```

for the full backup and restore process.

## Host Bootstrap

The target production system is Debian 13.

A fresh VPS can be prepared with:

```bash
git clone <repository-url> /opt/vps-infra
cd /opt/vps-infra

sudo ./scripts/bootstrap.sh
```

The bootstrap script handles:

* base system packages
* Docker Engine
* Docker Compose plugin
* Docker log rotation
* deployment user
* swap
* firewall
* unattended security updates
* shared Docker networks
* backup directories
* systemd timers

After bootstrap:

```bash
cp .env.example .env
chmod 600 .env
```

Configure secrets and deploy:

```bash
make deploy
make health
```

See:

```text
docs/SETUP.md
```

for the complete process.

## Application Deployment

Applications are deployed independently.

The intended flow is:

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

Application images should be built by GitHub Actions rather than on the VPS.

Applications live under:

```text
/opt/apps/<project>
```

For example:

```text
/opt/apps/project-a
/opt/apps/project-b
```

Shared infrastructure remains under:

```text
/opt/vps-infra
```

The separation is intentional:

```text
vps-infra
    |
    ├── machine
    ├── networking
    ├── shared services
    ├── monitoring
    └── backups

application repository
    |
    ├── application
    ├── workers
    ├── Celery
    ├── migrations
    ├── CI
    └── CD
```

Application deployments must not recreate or restart shared infrastructure.

Infrastructure deployments must not redeploy applications.

## Object Storage

Production object storage uses Cloudflare R2.

Applications should use generic S3-compatible configuration:

```dotenv
S3_ENDPOINT=
S3_ACCESS_KEY_ID=
S3_SECRET_ACCESS_KEY=
S3_BUCKET=
S3_REGION=
```

Application-specific R2 credentials belong to the application repository's deployment secrets.

For ephemeral data, lifecycle policies should be configured directly in R2 rather than using VPS cron jobs where possible.

## Documentation

Detailed documentation is available under:

```text
docs/
```

* `SETUP.md` — initial VPS provisioning
* `ADDING-A-PROJECT.md` — connecting new applications to shared infrastructure
* `DEPLOYMENT.md` — application deployment model and GitHub Actions architecture
* `BACKUPS.md` — PostgreSQL backup and restore strategy
* `OBSERVABILITY.md` — Prometheus, Grafana, and exporters
