ARG VERSION=2.15.3
ARG PYTHON=3.12
ARG UID=200005
ARG GID=200005

FROM ghcr.io/paperless-ngx/paperless-ngx:latest AS extract

# ======================================= #

# We have to pin Alpine version here, as not all dependencies will be immediately
# available in the latest Alpine version
FROM python:${PYTHON}-alpine

LABEL maintainer="Thien Tran contact@tommytran.io"

ARG VERSION
ARG UID
ARG GID

# Set Python environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PNGX_CONTAINERIZED=1 \
    # https://docs.astral.sh/uv/reference/settings/#link-mode
    UV_LINK_MODE=copy \
    UV_CACHE_DIR=/cache/uv/

RUN apk -U upgrade \
    && apk add -u bash coreutils curl git libstdc++ py3-zxing-cpp s6-overlay tzdata \
        font-liberation gettext ghostscript gnupg imagemagick \
        mariadb-client postgresql17-client \
        tesseract-ocr tesseract-ocr-data-eng tesseract-ocr-data-osd \
        unpaper pngquant jbig2dec libxml2 libxslt qpdf \
        file libmagic zlib \
        libzbar poppler-utils

# Setup s6
RUN git clone https://github.com/paperless-ngx/paperless-ngx --branch v${VERSION} \
    && mv paperless-ngx/docker/rootfs/ / \
    && chmod +x /usr/local/bin \
    && rm -rf paperless-ngx

WORKDIR /usr/src/paperless/src/

 # Python dependencies
# Change pretty frequently
COPY --from=extract --chown=1000:1000 /usr/src/paperless/src/ /usr/src/paperless/src/
        
RUN --mount=type=cache,target=/root/.cache/pip/,id=pip-cache \
    apk add -u --virtual .build-deps build-base libpq-dev mariadb-connector-c-dev pkgconf \
    && python3 -m pip install --no-cache-dir --upgrade wheel \
    && python3 -m pip install --default-timeout=1000 --find-links . --requirement requirements.txt \
    && python3 -m nltk.downloader -d "/usr/share/nltk_data" snowball_data \
    && python3 -m nltk.downloader -d "/usr/share/nltk_data" stopwords \
    && python3 -m nltk.downloader -d "/usr/share/nltk_data" punkt_tab \
    && apk del .build-deps \
    && apk del git \
    && rm -rf /var/cache/apk/* /var/tmp/* /tmp/* 

RUN --network=none \
    addgroup -g ${GID} paperless \
    && adduser -u ${UID} --ingroup paperless --disabled-password --system --home /usr/src/paperless paperless \
    && chown -R paperless:paperless /usr/src/paperless

USER paperless

# Copy backend & frontend
COPY --from=extract --chown=paperless:paperless /usr/src/paperless/ /usr/src/paperless/

COPY --from=ghcr.io/polarix-containers/hardened_malloc:latest /install /usr/local/lib/
ENV LD_PRELOAD="/usr/local/lib/libhardened_malloc.so"

VOLUME ["/usr/src/paperless/data", \
        "/usr/src/paperless/media", \
        "/usr/src/paperless/consume", \
        "/usr/src/paperless/export"]

EXPOSE 8000/tcp

ENTRYPOINT ["/init"]

HEALTHCHECK --interval=30s --timeout=10s --retries=5 CMD [ "curl", "-fs", "-S", "--max-time", "2", "http://localhost:8000" ]
