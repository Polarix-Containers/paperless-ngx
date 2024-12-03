FROM ghcr.io/paperless-ngx/paperless-ngx:latest

LABEL maintainer="Thien Tran contact@tommytran.io"

COPY etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources

RUN apt update \
    && apt upgrade -y \
    && apt purge -y gosu

RUN apt purge -y postgres*