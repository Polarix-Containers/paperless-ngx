ARG ALPINE=3.20
ARG PYTHON=3.12

FROM ghcr.io/paperless-ngx/paperless-ngx:latest as extract

FROM python:${PYTHON}-alpine${ALPINE}

# Set Python environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    # Ignore warning from Whitenoise
    PYTHONWARNINGS="ignore:::django.http.response:517" \
    PNGX_CONTAINERIZED=1

# Missing icc-profiles-free and tesseract-ocr languages

RUN apk -U upgrade \
    && apk add -u bash coreutils curl font-liberation gettext ghostscript imagemagick gnupg mariadb-client tesseract-ocr tzdata unpaper pngquant jbig2dec libxml2 libxslt qpdf file libmagic zlib libzbar poppler-utils \
    && rm -rf /var/cache/apk/*

RUN python3 -m pip install --default-timeout=1000 --upgrade --no-cache-dir supervisor==4.2.5

# Copy gunicorn config
# Changes very infrequently
WORKDIR /usr/src/paperless/

COPY --from=extract /usr/src/paperless/gunicorn.conf.py .

# setup docker-specific things
# These change sometimes, but rarely
WORKDIR /usr/src/paperless/src/docker/

COPY --from=ghcr.io/polarix-containers/hardened_malloc:latest /install /usr/local/lib/
ENV LD_PRELOAD="/usr/local/lib/libhardened_malloc.so"