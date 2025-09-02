ARG VERSION=2.18.2
ARG NODE=20
ARG PYTHON=3.12
ARG UV=0.8.8
ARG S6=3.2.1.0
ARG UID=200005
ARG GID=200005


FROM node:${NODE}-alpine AS compile-frontend
ARG VERSION

ADD https://github.com/paperless-ngx/paperless-ngx.git#v${VERSION}:src-ui /src/src-ui
WORKDIR /src/src-ui

RUN apk -U upgrade \
    && npm update -g pnpm \
    && npm install -g corepack@latest \
    && corepack enable \
    && pnpm install \
    && ./node_modules/.bin/ng build --configuration production


# ======================================= #


FROM ghcr.io/astral-sh/uv:${UV}-python${PYTHON}-alpine AS s6-overlay-base

ARG TARGETARCH
ARG TARGETVARIANT
ARG VERSION
ARG S6

WORKDIR /usr/src/s6

# https://github.com/just-containers/s6-overlay#customizing-s6-overlay-behaviour
ARG S6_BEHAVIOUR_IF_STAGE2_FAILS=2
ARG S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0
ARG S6_VERBOSITY=1
ARG PATH=/command:$PATH

RUN apk add bash curl \
    && if [ "${TARGETARCH}${TARGETVARIANT}" = "amd64" ]; then \
        S6_ARCH="x86_64"; \
    elif [ "${TARGETARCH}${TARGETVARIANT}" = "arm64" ]; then \
        S6_ARCH="aarch64"; \
    fi \
    && curl --fail --silent --no-progress-meter --show-error --location --remote-name-all --parallel --parallel-max 4 \
        "https://github.com/just-containers/s6-overlay/releases/download/v${S6}/s6-overlay-noarch.tar.xz" \
        "https://github.com/just-containers/s6-overlay/releases/download/v${S6}/s6-overlay-noarch.tar.xz.sha256" \
        "https://github.com/just-containers/s6-overlay/releases/download/v${S6}/s6-overlay-${S6_ARCH}.tar.xz" \
        "https://github.com/just-containers/s6-overlay/releases/download/v${S6}/s6-overlay-${S6_ARCH}.tar.xz.sha256" \
    && sha256sum -c ./*.sha256 \
    && tar --directory / -Jxpf s6-overlay-noarch.tar.xz \
    && tar --directory / -Jxpf s6-overlay-${S6_ARCH}.tar.xz \
    && rm ./*.tar.xz && rm ./*.sha256

# Copy our service defs and filesystem
ADD https://github.com/paperless-ngx/paperless-ngx.git#v${VERSION}:docker ./docker
RUN cp -r docker/rootfs/* / \
    && rm -rf docker

# ======================================= #

FROM s6-overlay-base AS main-app
LABEL maintainer="Thien Tran contact@tommytran.io"

ARG VERSION
ARG UID
ARG GID

# Set Python environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    # Ignore warning from Whitenoise about async iterators
    PYTHONWARNINGS="ignore:::django.http.response:517" \
    PNGX_CONTAINERIZED=1 \
    # https://docs.astral.sh/uv/reference/settings/#link-mode
    UV_LINK_MODE=copy \
    UV_CACHE_DIR=/cache/uv/

# Install dependencies

RUN apk -U upgrade \
    && apk add -u bash coreutils libstdc++ tzdata \
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


RUN apk add -u --virtual .build-deps build-base git mariadb-connector-c-dev pkgconf \
    && uv export --quiet --no-dev --all-extras --format requirements-txt --output-file requirements.txt \
    && uv pip install --system --no-python-downloads --python-preference system --requirements requirements.txt \
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
    && chown -R paperless:paperless /usr/src/paperless
#    && s6-setuidgid paperless python3 manage.py collectstatic --clear --no-input --link \
#    && s6-setuidgid paperless python3 manage.py compilemessages

# USER paperless

# Copy backend
ADD --chown=paperless:paperless https://github.com/paperless-ngx/paperless-ngx.git#v${VERSION}:src .

# Copy frontend
COPY --from=compile-frontend --chown=paperless:paperless /src/src/documents/static/frontend/ ./documents/static/frontend/

COPY --from=ghcr.io/polarix-containers/hardened_malloc:latest /install /usr/local/lib/
ENV LD_PRELOAD="/usr/local/lib/libhardened_malloc.so"

VOLUME ["/usr/src/paperless/data", \
        "/usr/src/paperless/media", \
        "/usr/src/paperless/consume", \
        "/usr/src/paperless/export"]

EXPOSE 8000/tcp

ENTRYPOINT ["/init"]

HEALTHCHECK --interval=30s --timeout=10s --retries=5 CMD [ "curl", "-fs", "-S", "-L", "--max-time", "2", "http://localhost:8000" ]
