# Backups

PostgreSQL backups are handled by `vps-infra`.

The current policy is:

- weekly PostgreSQL backup
- local compressed backup
- optional upload to Cloudflare R2
- local backup retention
- manual disaster-recovery restore

## Schedule

The backup runs every Sunday at 03:00.

Systemd timer:

```ini
[Unit]
Description=Weekly PostgreSQL backup

[Timer]
OnCalendar=Sun *-*-* 03:00:00
Persistent=true
Unit=postgres-backup.service

[Install]
WantedBy=timers.target
```

`Persistent=true` means that if the VPS is offline when the backup should run, systemd can execute the missed job after the machine starts again.

## Local backups

Backups are stored under:

```text
/var/backups/vps-infra/postgres/
```

Example:

```text
postgres-2026-08-16T03-00-00Z.sql.gz
```

The backup contains all PostgreSQL roles and databases.

## Cloudflare R2

Production should upload database backups off-server.

Enable R2 backups in `.env`:

```dotenv
R2_BACKUP_ENABLED=true

R2_ACCOUNT_ID=
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
R2_BACKUP_BUCKET=vps-backups

BACKUP_RETENTION_DAYS=7
```

The R2 bucket should be dedicated to infrastructure backups.

Example object layout:

```text
vps-backups/
└── postgres/
    ├── postgres-2026-08-16T03-00-00Z.sql.gz
    ├── postgres-2026-08-23T03-00-00Z.sql.gz
    └── postgres-2026-08-30T03-00-00Z.sql.gz
```

## Why backups leave the VPS

A backup stored only on the VPS does not protect against:

- disk failure
- accidental VPS deletion
- provider failure
- filesystem corruption
- destructive administrative mistakes

Therefore:

```text
PostgreSQL
    |
    v
local compressed dump
    |
    v
Cloudflare R2
```

The off-server copy is the important one.

## Manual backup

Run:

```bash
cd /opt/vps-infra
make backup
```

Or directly:

```bash
sudo ./scripts/backup.sh
```

## Inspect backup timer

Check whether the timer is enabled:

```bash
systemctl status postgres-backup.timer
```

List upcoming executions:

```bash
systemctl list-timers postgres-backup.timer
```

Inspect previous backup executions:

```bash
journalctl -u postgres-backup.service
```

Show the most recent logs:

```bash
journalctl -u postgres-backup.service -n 100
```

## Restore

Restores are intended primarily for disaster recovery onto a fresh PostgreSQL instance.

Example:

```bash
make restore FILE=/var/backups/vps-infra/postgres/postgres-2026-08-16T03-00-00Z.sql.gz
```

The restore contains all databases and PostgreSQL roles present when the backup was created.

Use restore operations carefully.

## Retention

Local backup retention is controlled through:

```dotenv
BACKUP_RETENTION_DAYS=7
```

This controls only local backup cleanup.

R2 retention should be configured separately according to the desired backup policy.

Since backups currently run weekly, R2 should normally retain multiple weeks or months of snapshots.
