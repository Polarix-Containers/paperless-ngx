ARG PYTHON=3.12
ARG UID=200005
ARG GID=200005

FROM ghcr.io/paperless-ngx/paperless-ngx:latest AS extract

# ======================================= #

# We have to pin Alpine version here, as not all dependencies will be immediately
# available in the latest Alpine version
FROM python:${PYTHON}-alpine

LABEL maintainer="Thien Tran contact@tommytran.io"

ARG UID
ARG GID

RUN apk -U upgrade \
    && apk add -u bash coreutils curl libstdc++ s6-overlay tzdata \
        font-liberation gettext ghostscript gnupg imagemagick \
        mariadb-client postgresql17-client \
        tesseract-ocr tesseract-ocr-data-eng tesseract-ocr-data-osd \
        unpaper pngquant jbig2dec libxml2 libxslt qpdf \
        file libmagic zlib \
        libzbar poppler-utils