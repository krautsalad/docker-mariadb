# docker-mariadb

MariaDB with memory tuning, optional slow-query logging, and scheduled table optimization.

**docker-mariadb** extends the official [MariaDB Docker image](https://hub.docker.com/_/mariadb). At startup it generates a tuned `my.cnf` from environment variables, runs MariaDB under supervisord together with cron, and can schedule `mariadb-check --optimize` jobs.

## Configuration

### Docker Compose Example

```yml
# docker-compose.yml
services:
  mariadb:
    container_name: mariadb
    environment:
      LONG_QUERY_TIME: 3
      MARIADB_AUTO_UPGRADE: true
      MARIADB_DATABASE: example
      MARIADB_PASSWORD: VerySecurePassword
      MARIADB_ROOT_PASSWORD: VerySecurePassword
      MARIADB_USER: example
      MEMORY_GB: 2
      OPTIMIZE_ENABLED: 1
      OPTIMIZE_SCHEDULE: 0 1 * * 6
      SLOW_QUERY_LOG: 1
      TZ: Europe/Berlin
    healthcheck:
      interval: 30s
      retries: 10
      start_period: 10s
      test: [ "CMD", "healthcheck.sh", "--connect", "--innodb_initialized", "--mariadbupgrade" ]
      timeout: 10s
    image: krautsalad/mariadb
    ports:
      - "3306:3306"
    restart: unless-stopped
    security_opt:
      - seccomp:unconfined
    volumes:
      - ./mariadb-config/my.cnf:/etc/mysql/conf.d/zz-overrides.cnf:ro
      - ./mariadb-logs:/var/log/mysql
      - ./mariadb-data:/var/lib/mysql
```

### Environment Variables

#### Image-specific

| Variable | Default | Description |
| --- | --- | --- |
| `LONG_QUERY_TIME` | `3` | Queries running longer than this many seconds are logged when slow query logging is enabled. |
| `MEMORY_GB` | `0.5` | Memory budget for the database in gigabytes (minimum `0.5`). |
| `OPTIMIZE_ENABLED` | `0` | Enables the cron job which reorganizes table storage and indexes to reduce fragmentation and reclaim unused space. |
| `OPTIMIZE_SCHEDULE` | `0 1 * * 6` | Cron expression for the optimize job (default: Saturday at 01:00). Only used when the cron job is enabled. |
| `SLOW_QUERY_LOG` | `0` | Enables slow query logging. |

#### Official

This image supports the upstream variables. Common ones:

| Variable | Default | Description |
| --- | --- | --- |
| `MARIADB_AUTO_UPGRADE` | — | Run `mariadb-upgrade` on start when needed. |
| `MARIADB_DATABASE` | — | Database created on first start. |
| `MARIADB_PASSWORD` | — | Password for `MARIADB_USER`. |
| `MARIADB_ROOT_PASSWORD` | — | Root password. |
| `MARIADB_USER` | — | Non-root user created on first start (used with `MARIADB_PASSWORD`). |
| `TZ` | `UTC` | Timezone. |

See the [official documentation](https://hub.docker.com/_/mariadb) for the full list.

## How it works

At container start, the custom entrypoint reads the tuning variables, substitutes placeholders in `my.cnf.template`, and writes `/etc/mysql/conf.d/zz-overrides-initial.cnf`. You can optionally override MariaDB settings further by mounting a custom `my.cnf` to `/etc/mysql/conf.d/zz-overrides.cnf`, as in the Docker Compose example above. If `OPTIMIZE_ENABLED` is on, it installs a cron file at `/etc/cron.d/mariadb-optimize`.

Supervisord then starts MariaDB (via the official image entrypoint) and `crond` for scheduled jobs. Database files are stored under `/var/lib/mysql`; mount a volume there to persist data.

## Source Code

You can find the full source code on [GitHub](https://github.com/krautsalad/docker-mariadb).
