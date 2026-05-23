#!/bin/bash
set -eo pipefail
shopt -s nullglob

mkdir -p /var/log/cron /var/log/mysql
chown mysql:mysql /var/log/mysql
ln -sf /proc/$$/fd/1 /var/log/cron/cron.log

# see mariabdb-docker/entrypoint.sh
file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local def="${2:-}"
    if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
        echo "Error: Both $var and $fileVar are set (exclusive)" >&2
        exit 1
    fi
    local val="$def"
    if [ "${!var:-}" ]; then
        val="${!var}"
    elif [ "${!fileVar:-}" ]; then
        val="$(< "${!fileVar}")"
    fi
    export "$var"="$val"
    unset "$fileVar"
}
file_env 'MARIADB_ROOT_PASSWORD'

# setup cronjob
OPTIMIZE_ENABLED="${OPTIMIZE_ENABLED:-0}"
OPTIMIZE_SCHEDULE="${OPTIMIZE_SCHEDULE:-0 1 * * 6}"

rm -f /etc/cron.d/mariadb-optimize

if [[ "$(printf '%s' "$OPTIMIZE_ENABLED" | tr '[:upper:]' '[:lower:]')" =~ ^(1|on|true|yes)$ ]]; then
    if [ -n "${MARIADB_ROOT_PASSWORD:-}" ]; then
        echo "${OPTIMIZE_SCHEDULE} root mariadb-check -p${MARIADB_ROOT_PASSWORD} -u root --all-databases --optimize >> /var/log/cron/cron.log 2>&1" > /etc/cron.d/mariadb-optimize
    else
        echo "${OPTIMIZE_SCHEDULE} root mariadb-check -u root --all-databases --optimize >> /var/log/cron/cron.log 2>&1" > /etc/cron.d/mariadb-optimize
    fi
fi

# database parameters
SLOW_QUERY_LOG="${SLOW_QUERY_LOG:-0}"
long_query_time="${LONG_QUERY_TIME:-3}"
memory_gb=$(awk -v gb="${MEMORY_GB:-0.5}" 'BEGIN {
    if (gb + 0 < 0.5) gb = 0.5
    printf "%g", gb + 0
}')

if [[ "$(printf '%s' "${SLOW_QUERY_LOG}" | tr '[:upper:]' '[:lower:]')" =~ ^(1|on|true|yes)$ ]]; then
    slow_query_log=1
else
    slow_query_log=0
fi

# see database.gkanev.com
innodb_buffer_pool_size=$(awk -v gb="$memory_gb" 'BEGIN { printf "%dM", gb * 6656 / 10 }')
innodb_io_capacity=$(awk -v gb="$memory_gb" 'BEGIN { c = gb * 80; if (c < 100) c = 100; printf "%d", c }')
innodb_io_capacity_max=$(awk -v c="$innodb_io_capacity" 'BEGIN { printf "%d", c * 2 }')
innodb_log_file_size=$(awk -v gb="$memory_gb" 'BEGIN { printf "%dM", gb * 6656 / 10 * 25 / 100 }')
key_buffer_size=$(awk -v gb="$memory_gb" 'BEGIN { printf "%dM", gb * 1024 / 10 }')
max_heap_table_size=$(awk -v gb="$memory_gb" 'BEGIN { printf "%dM", gb * 4096 / 100 }')
tmp_table_size=$(awk -v gb="$memory_gb" 'BEGIN { printf "%dM", gb * 4096 / 100 }')

sed \
    -e "s/@INNODB_BUFFER_POOL_SIZE@/${innodb_buffer_pool_size}/g" \
    -e "s/@INNODB_IO_CAPACITY_MAX@/${innodb_io_capacity_max}/g" \
    -e "s/@INNODB_IO_CAPACITY@/${innodb_io_capacity}/g" \
    -e "s/@INNODB_LOG_FILE_SIZE@/${innodb_log_file_size}/g" \
    -e "s/@KEY_BUFFER_SIZE@/${key_buffer_size}/g" \
    -e "s/@LONG_QUERY_TIME@/${long_query_time}/g" \
    -e "s/@MAX_HEAP_TABLE_SIZE@/${max_heap_table_size}/g" \
    -e "s/@MEMORY_GB@/${memory_gb}/g" \
    -e "s/@SLOW_QUERY_LOG@/${slow_query_log}/g" \
    -e "s/@TMP_TABLE_SIZE@/${tmp_table_size}/g" \
    /usr/local/share/mariadb/my.cnf.template > /etc/mysql/conf.d/zz-overrides-initial.cnf

# drop stale mariadb-ubi healthcheck config
if [ -f /var/lib/mysql/.my-healthcheck.cnf ] && grep -qF 'socket=/run/mariadb/mariadb.sock' /var/lib/mysql/.my-healthcheck.cnf; then
    rm -f /var/lib/mysql/.my-healthcheck.cnf
fi

exec /usr/bin/tini -- /usr/bin/supervisord -c /etc/supervisord.conf
