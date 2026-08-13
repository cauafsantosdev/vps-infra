# Observability

The shared observability stack contains:

- Prometheus
- Grafana
- Node Exporter
- cAdvisor
- PostgreSQL Exporter

The goal is to understand:

- VPS resource usage
- container resource usage
- PostgreSQL health
- application behavior
- capacity limits

## Architecture

```text
Node Exporter ───────┐
                     |
cAdvisor ────────────┤
                     |
PostgreSQL Exporter ─┼──> Prometheus ───> Grafana
                     |
Application /metrics ┘
```

## Prometheus

Prometheus collects and stores time-series metrics.

Current configuration:

```text
scrape interval: 30 seconds
retention time: 15 days
retention size: 2 GB
```

Prometheus listens only on:

```text
127.0.0.1:9090
```

It is not exposed directly to the public Internet.

### Access Prometheus

Create an SSH tunnel:

```bash
ssh -L 9090:127.0.0.1:9090 deploy@SERVER
```

Then open:

```text
http://localhost:9090
```

## Node Exporter

Node Exporter exposes metrics about the Debian host.

Examples:

- CPU usage
- memory usage
- filesystem usage
- load average
- disk I/O
- network activity

Example Prometheus metrics:

```text
node_cpu_seconds_total
node_memory_MemAvailable_bytes
node_filesystem_avail_bytes
```

## cAdvisor

cAdvisor exposes container-level metrics.

Examples:

- container CPU usage
- container memory usage
- network traffic
- filesystem usage

This helps answer questions such as:

```text
How much RAM is Lexos using?

Which container is consuming CPU?

Did a Celery worker cause a memory spike?
```

## PostgreSQL Exporter

PostgreSQL Exporter exposes PostgreSQL statistics to Prometheus.

Examples include:

- database activity
- connections
- transactions
- locks
- database size
- PostgreSQL internal statistics

It connects to PostgreSQL internally through `vps-data`.

It is not publicly exposed.

## Grafana

Grafana queries Prometheus and provides dashboards.

Grafana listens only on:

```text
127.0.0.1:3000
```

It is not initially exposed publicly.

### Access Grafana

Create an SSH tunnel:

```bash
ssh -L 3000:127.0.0.1:3000 deploy@SERVER
```

Then open:

```text
http://localhost:3000
```

Credentials are configured through:

```dotenv
GRAFANA_ADMIN_USER=
GRAFANA_ADMIN_PASSWORD=
```

## Initial dashboard

The repository includes a basic VPS dashboard showing:

- CPU usage
- memory usage
- root filesystem usage
- container memory usage

Additional dashboards can be added under:

```text
grafana/dashboards/
```

## Application metrics

Applications may expose Prometheus metrics through an endpoint such as:

```text
/metrics
```

For example, Lexos could eventually expose:

```text
lexos_tasks_total
lexos_tasks_failed_total
lexos_task_duration_seconds
lexos_cache_hits_total
lexos_cache_misses_total
```

A recommendation API might expose:

```text
recommendation_requests_total
recommendation_latency_seconds
retrieval_latency_seconds
```

Applications exposing metrics should join:

```text
vps-monitoring
```

Prometheus can then scrape them directly through Docker networking.

## Useful checks

Show infrastructure containers:

```bash
docker compose ps
```

Show live container resource usage:

```bash
docker stats
```

Check Prometheus health:

```bash
curl http://127.0.0.1:9090/-/healthy
```

Check Grafana health:

```bash
curl http://127.0.0.1:3000/api/health
```
