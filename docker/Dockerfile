FROM mariadb:12.2

ENV DEBIAN_FRONTEND=noninteractive

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends cron supervisor tini && \
    apt-get clean && \
    rm -rf /root/.cache /tmp/* /var/tmp/* /var/lib/apt/lists/* && \
    mkdir -p /var/log/mysql && \
    chown mysql:mysql /var/log/mysql && \
    mv /usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint-mariadb.sh

COPY docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY docker/my.cnf /usr/local/share/mariadb/my.cnf.template
COPY docker/supervisord.conf /etc/supervisord.conf

ENTRYPOINT ["docker-entrypoint.sh"]
