FROM ghcr.io/paperless-ngx/paperless-ngx:latest

LABEL maintainer="Thien Tran contact@tommytran.io"

RUN apt update \
    && apt upgrade -y \
    && apt purge -y gosu
