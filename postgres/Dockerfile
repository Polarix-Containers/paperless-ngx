FROM ghcr.io/paperless-ngx/paperless-ngx:latest

LABEL maintainer="Thien Tran contact@tommytran.io"

COPY etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources

RUN env DEBIAN_FRONTEND=noninteractive apt-get update \
    && env DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y \
    && env DEBIAN_FRONTEND=noninteractive apt-get purge -y gosu

RUN env DEBIAN_FRONTEND=noninteractive apt-get purge -y mariadb* postgres*
