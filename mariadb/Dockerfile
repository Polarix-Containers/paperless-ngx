FROM python:3.12-alpine

# Can be workflow provided, defaults set for manual building
ARG JBIG2ENC_VERSION=0.29
ARG QPDF_VERSION=11.9.0
ARG GS_VERSION=10.03.1

# Set Python environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    # Ignore warning from Whitenoise
    PYTHONWARNINGS="ignore:::django.http.response:517" \
    PNGX_CONTAINERIZED=1

# Missing icc-profiles-free

RUN apk -U upgrade \
    && apk add -u bash coreutils curl font-liberation gettext ghostscript icc-profiles-free imagemagick gnupg mariadb-client tesseract-ocr tzdata unpaper pngquant jbig2dec libxml2 libxslt qpdf file libmagic zlib libzbar poppler-utils \
    && rm -rf /var/cache/apk/*