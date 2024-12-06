ARG ALPINE=3.20
ARG PYTHON=3.12
ARG UID=3007
ARG GID=3007

FROM ghcr.io/paperless-ngx/paperless-ngx:latest as extract

FROM python:${PYTHON}-alpine${ALPINE}

ARG UID
ARG GID

# Set Python environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    # Ignore warning from Whitenoise
    PYTHONWARNINGS="ignore:::django.http.response:517" \
    PNGX_CONTAINERIZED=1

# Missing icc-profiles-free and tesseract-ocr languages

RUN apk -U upgrade \
    && apk add -u bash coreutils curl font-liberation gettext ghostscript imagemagick gnupg mariadb-client tesseract-ocr tzdata unpaper pngquant jbig2dec libxml2 libxslt qpdf file libmagic zlib libzbar poppler-utils supervisor \
    && rm -rf /var/cache/apk/*

# Copy gunicorn config
# Changes very infrequently
WORKDIR /usr/src/paperless/

COPY --from=extract /usr/src/paperless/gunicorn.conf.py .

# setup docker-specific things
# These change sometimes, but rarely
WORKDIR /usr/src/paperless/src/docker/

# add users, setup scripts
# Mount the compiled frontend to expected location

RUN addgroup -g ${GID} paperless \
    && adduser -u ${UID} --ingroup paperless --disabled-password --system --home /usr/src/paperless paperless

RUN mkdir -p /usr/src/paperless/data /usr/src/paperless/media /usr/src/paperless/consume /usr/src/paperless/export \
    && mkdir -m700 --verbose /usr/src/paperless/.gnupg \
    && chown -R paperless:paperless /usr/src/paperless

USER paperless
#RUN  python3 manage.py collectstatic --clear --no-input --link \
#    && python3 manage.py compilemessages

COPY --from=ghcr.io/polarix-containers/hardened_malloc:latest /install /usr/local/lib/
ENV LD_PRELOAD="/usr/local/lib/libhardened_malloc.so"

VOLUME ["/usr/src/paperless/data", \
        "/usr/src/paperless/media", \
        "/usr/src/paperless/consume", \
        "/usr/src/paperless/export"]

EXPOSE 8000/tcp

ENTRYPOINT ["/sbin/docker-entrypoint.sh"]

HEALTHCHECK --interval=30s --timeout=10s --retries=5 CMD [ "curl", "-fs", "-S", "--max-time", "2", "http://localhost:8000" ]
CMD ["/usr/local/bin/paperless_cmd.sh"]
