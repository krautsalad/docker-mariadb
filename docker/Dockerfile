FROM mariadb:12.2-ubi

USER root

RUN microdnf install -y cronie supervisor tini && \
    microdnf clean all && \
    mkdir -p /var/log/mysql && \
    chown mysql:mysql /var/log/mysql && \
    mv /usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint-mariadb.sh

COPY docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY docker/my.cnf /usr/local/share/mariadb/my.cnf.template
COPY docker/supervisord.conf /etc/supervisord.conf

ENTRYPOINT ["docker-entrypoint.sh"]
