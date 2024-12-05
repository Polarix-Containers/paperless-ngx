FROM ghcr.io/paperless-ngx/paperless-ngx:latest

LABEL maintainer="Thien Tran contact@tommytran.io"

COPY etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources

RUN env DEBIAN_FRONTEND=noninteractive apt update \
    && env DEBIAN_FRONTEND=noninteractive apt full-upgrade -y \
    && env DEBIAN_FRONTEND=noninteractive apt purge -y gosu

RUN env DEBIAN_FRONTEND=noninteractive apt purge -y mariadb* postgres*
