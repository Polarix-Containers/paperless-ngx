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

# add users, setup scripts
# Mount the compiled frontend to expected location
RUN echo "Setting up user/group" \
    && addgroup --gid 1000 paperless \
    && useradd --uid 1000 --gid paperless --home-dir /usr/src/paperless paperless \
    && echo "Creating volume directories" \
    && mkdir --parents --verbose /usr/src/paperless/data \
    && mkdir --parents --verbose /usr/src/paperless/media \
    && mkdir --parents --verbose /usr/src/paperless/consume \
    && mkdir --parents --verbose /usr/src/paperless/export \
    && echo "Creating gnupg directory" \
    && mkdir -m700 --verbose /usr/src/paperless/.gnupg \
    && echo "Adjusting all permissions" \
    && chown --from root:root --changes --recursive paperless:paperless /usr/src/paperless \
    && echo "Collecting static files"
#    && gosu paperless python3 manage.py collectstatic --clear --no-input --link \
#    && gosu paperless python3 manage.py compilemessages

COPY --from=ghcr.io/polarix-containers/hardened_malloc:latest /install /usr/local/lib/
ENV LD_PRELOAD="/usr/local/lib/libhardened_malloc.so"

VOLUME ["/usr/src/paperless/data", \
        "/usr/src/paperless/media", \
        "/usr/src/paperless/consume", \
        "/usr/src/paperless/export"]

EXPOSE 8000

ENTRYPOINT ["/sbin/docker-entrypoint.sh"]

HEALTHCHECK --interval=30s --timeout=10s --retries=5 CMD [ "curl", "-fs", "-S", "--max-time", "2", "http://localhost:8000" ]
CMD ["/usr/local/bin/paperless_cmd.sh"]