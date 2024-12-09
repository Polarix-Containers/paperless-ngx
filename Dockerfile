ARG ALPINE=3.20
ARG PYTHON=3.12
ARG UID=3007
ARG GID=3007

FROM ghcr.io/paperless-ngx/paperless-ngx:latest AS extract

# We have to pin Alpine version here, as not all dependencies will be immediately
# available in the latest Alpine version
FROM python:${PYTHON}-alpine${ALPINE}

LABEL maintainer="Thien Tran contact@tommytran.io"

ARG UID
ARG GID

# Set Python environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PNGX_CONTAINERIZED=1

# Install dependencies
# Alpine does not have icc-profiles-free

RUN apk -U upgrade \
    && apk add -u bash coreutils curl libstdc++ supervisor tzdata \
        font-liberation gettext ghostscript gnupg imagemagick \
        postgresql16-client py3-psycopg-c-pyc \
        mariadb-client \ 
        tesseract-ocr tesseract-ocr-data-eng tesseract-ocr-data-deu tesseract-ocr-data-fra tesseract-ocr-data-ita tesseract-ocr-data-spa \
        unpaper pngquant jbig2dec libxml2 libxslt qpdf \
        file libmagic zlib \
        libzbar poppler-utils

# Create necessary directories
RUN mkdir -p /usr/src/paperless/src/docker

# Copy gunicorn config
COPY --from=extract /usr/src/paperless/gunicorn.conf.py /usr/src/paperless/

# Copy docker specific files
COPY --from=extract /etc/ImageMagick-6/policy.xml /etc/ImageMagick-6/
COPY --from=extract /etc/supervisord.conf /etc/
COPY --from=extract --chmod=755 /sbin/docker-entrypoint.sh /sbin/
COPY --from=extract --chmod=755 /sbin/docker-prepare.sh /sbin/
COPY --from=extract --chmod=755 /sbin/wait-for-redis.py /sbin/
COPY --from=extract --chmod=755 /sbin/env-from-file.sh /sbin/
COPY --from=extract --chmod=755 /usr/local/bin/paperless_cmd.sh /usr/local/bin
COPY --from=extract --chmod=755 /usr/local/bin/flower-conditional.sh /usr/local/bin/
COPY --from=extract --chmod=755 /usr/src/paperless/src/docker/install_management_commands.sh /usr/src/paperless/src/docker/
COPY --from=extract --chmod=755 /usr/src/paperless/src/docker/management_script.sh /usr/src/paperless/src/docker/

# Copy requirements.txt
COPY --from=extract /usr/src/paperless/src/requirements.txt /usr/src/paperless/src/

WORKDIR /usr/src/paperless/src/

RUN --mount=type=cache,target=/root/.cache/pip/,id=pip-cache \
    apk add -u --virtual .build-deps build-base git libpq-dev mariadb-connector-c-dev pkgconf \
    && python3 -m pip install --no-cache-dir --upgrade wheel \
    && python3 -m pip install --default-timeout=1000 --find-links . --requirement requirements.txt \
    && python3 -m nltk.downloader -d "/usr/share/nltk_data" snowball_data \
    && python3 -m nltk.downloader -d "/usr/share/nltk_data" stopwords \
    && python3 -m nltk.downloader -d "/usr/share/nltk_data" punkt_tab \
    && apk del .build-deps \
    && rm -rf *.whl /var/cache/apt/archives/* /var/cache/apk/* /var/lib/apt/lists/* /var/tmp/* /tmp/* \
    && truncate --size 0 /var/log/*log

RUN addgroup -g ${GID} paperless \
    && adduser -u ${UID} --ingroup paperless --disabled-password --system --home /usr/src/paperless paperless

RUN mkdir -p /usr/src/paperless/data /usr/src/paperless/media /usr/src/paperless/consume /usr/src/paperless/export \
    && mkdir -m700 --verbose /usr/src/paperless/.gnupg \
    && chown -R paperless:paperless /usr/src/paperless

USER paperless

# Copy backend & frontend
COPY --from=extract --chown=paperless:paperless /usr/src/paperless/src/ ./

RUN python3 manage.py collectstatic --clear --no-input --link \
    && python3 manage.py compilemessages

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
