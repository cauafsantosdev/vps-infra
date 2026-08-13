# VPS Setup

The production host targets Debian 13.

## Initial installation

Install Git on the fresh VPS:

```bash
apt update
apt install -y git
```

Clone the repository:

```bash
git clone https://github.com/cauafsantosdev/vps-infra /opt/vps-infra
cd /opt/vps-infra
```

Bootstrap the host:

```bash
sudo ./scripts/bootstrap.sh
```

The bootstrap script prepares the host by:

- installing Docker Engine and Docker Compose
- installing base administration tools
- configuring Docker log rotation
- creating the deployment user
- creating swap
- configuring the firewall
- enabling unattended security updates
- creating shared Docker networks
- preparing backup directories

## Environment configuration

Create the production environment file:

```bash
cp .env.example .env
chmod 600 .env
```

Replace every placeholder password in `.env`.

Never commit `.env`.

## Deploy infrastructure

Validate the configuration:

```bash
make config
```

Deploy the shared infrastructure:

```bash
make deploy
```

Verify container status:

```bash
make status
```

Run health checks:

```bash
make health
```

## Shared Docker networks

The bootstrap creates the following external Docker networks:

- `vps-edge`
- `vps-data`
- `vps-monitoring`

### `vps-edge`

Used by Caddy and application services that receive HTTP traffic.

Example:

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

### `vps-data`

Used by application services that need access to shared infrastructure such as:

- PostgreSQL
- Redis

PostgreSQL and Redis are not exposed through host ports.

### `vps-monitoring`

Used by Prometheus, exporters, and application services that expose metrics.

## Directory layout

Shared infrastructure lives under:

```text
/opt/vps-infra
```

Applications should live under:

```text
/opt/apps/
```

For example:

```text
/opt/
├── vps-infra/
└── apps/
    ├── lexos/
    ├── nexdwatch/
    └── another-project/
```

## Useful commands

```bash
make help
make config
make deploy
make status
make logs
make health
```
