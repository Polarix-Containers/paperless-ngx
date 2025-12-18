ARG VERSION=2.20.3
ARG NODE=20
ARG PYTHON=3.12
ARG UV=0.9
ARG UID=200005
ARG GID=200005


FROM node:${NODE}-alpine AS compile-frontend
ARG VERSION

ADD https://github.com/paperless-ngx/paperless-ngx.git#v${VERSION}:src-ui /src/src-ui
WORKDIR /src/src-ui

RUN apk -U upgrade \
    && npm update -g npm \
    && npm update -g pnpm \
    && npm install -g corepack@latest \
    && corepack enable \
    && pnpm install \
    && ./node_modules/.bin/ng build --configuration production

# ======================================= #

FROM ghcr.io/astral-sh/uv:${UV}-python${PYTHON}-alpine
LABEL maintainer="Thien Tran contact@tommytran.io"

ARG VERSION
ARG UID
ARG GID

ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
    S6_VERBOSITY=1 \
    PATH=/command:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    # Ignore warning from Whitenoise about async iterators
    PYTHONWARNINGS="ignore:::django.http.response:517" \
    PNGX_CONTAINERIZED=1 \
    UV_COMPILE_BYTECODE=true \
    UV_NATIVE_TLS=true \
    UV_NO_CACHE=true \
    UV_NO_DEV=true \
    UV_NO_MANAGED_PYTHON=true \
    UV_PYTHON_DOWNLOADS=false

# Copy our service defs and filesystem
ADD https://github.com/paperless-ngx/paperless-ngx.git#v${VERSION}:docker /usr/src/s6/docker
RUN --network=none \
    cp -r /usr/src/s6/docker/rootfs/* / \
    && rm -rf /usr/src/s6/docker \
    && ln -s /bin/bash /usr/bin/bash \
    && mkdir -p /var/run/s6/container_environment

# Install dependencies
RUN apk -U upgrade \
    && apk add -u bash curl coreutils libstdc++ s6-overlay tzdata \
        font-liberation gettext ghostscript gnupg imagemagick \
        mariadb-client postgresql17-client \
        tesseract-ocr tesseract-ocr-data-eng tesseract-ocr-data-osd \
        unpaper pngquant jbig2dec libxml2 libxslt qpdf \
        file libmagic zlib \
        libzbar poppler-utils \
    && cp /etc/ImageMagick-6/paperless-policy.xml /etc/ImageMagick-6/policy.xml

WORKDIR /usr/src/paperless/src

ADD https://raw.githubusercontent.com/paperless-ngx/paperless-ngx/v${VERSION}/pyproject.toml /usr/src/paperless/src
ADD https://raw.githubusercontent.com/paperless-ngx/paperless-ngx/v${VERSION}/uv.lock /usr/src/paperless/src


RUN apk add -u --virtual .build-deps build-base git libpq-dev mariadb-connector-c-dev pkgconf \
#   https://github.com/astral-sh/uv/issues/8085
    && UV_PROJECT_ENVIRONMENT="$(python -c "import sysconfig; print(sysconfig.get_config_var('prefix'))")" \
    && export UV_PROJECT_ENVIRONMENT \
    && uv sync --all-extras --no-sources \
    && python3 -m nltk.downloader -d "/usr/share/nltk_data" snowball_data \
    && python3 -m nltk.downloader -d "/usr/share/nltk_data" stopwords \
    && python3 -m nltk.downloader -d "/usr/share/nltk_data" punkt_tab \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/* /var/tmp/* /tmp/* 

RUN --network=none \
    addgroup -g ${GID} paperless \
    && adduser -u ${UID} --ingroup paperless --disabled-password --system --home /usr/src/paperless paperless \
    && mkdir -p /usr/src/paperless/{data,media,consume,export} \
    && mkdir -m700 /usr/src/paperless/.gnupg \
    && chown -R paperless:paperless /usr/src/paperless /run

USER paperless

# Copy backend
ADD --chown=paperless:paperless https://github.com/paperless-ngx/paperless-ngx.git#v${VERSION}:src .

# Copy frontend
COPY --from=compile-frontend --chown=paperless:paperless /src/src/documents/static/frontend/ ./documents/static/frontend/

RUN sed -i '1s|^#!/usr/bin/env python3|#!/command/with-contenv python3|' manage.py \
    && python3 manage.py collectstatic --clear --no-input --link \
    && python3 manage.py compilemessages \
    && /usr/local/bin/deduplicate.py --verbose /usr/src/paperless/static/

COPY --from=ghcr.io/polarix-containers/hardened_malloc:latest /install /usr/local/lib/
ENV LD_PRELOAD="/usr/local/lib/libhardened_malloc.so"

VOLUME ["/usr/src/paperless/data", \
        "/usr/src/paperless/media", \
        "/usr/src/paperless/consume", \
        "/usr/src/paperless/export"]

EXPOSE 8000/tcp

ENTRYPOINT ["/init"]

HEALTHCHECK --interval=30s --timeout=10s --retries=5 CMD [ "curl", "-fs", "-S", "-L", "--max-time", "2", "http://localhost:8000" ]
