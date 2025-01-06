# Paperless-ngx

![Build, scan & push](https://github.com/Polarix-Containers/paperless-ngx/actions/workflows/build.yml/badge.svg)

### Features & usage
- Drop-in replacement for the [official image](https://github.com/paperless-ngx/paperless-ngx).
- Added `tesseract-ocr-data-osd`.
- Unprivileged image: you should check your volumes' permissions (eg `/data`), default UID/GID is 200005.
- Added support for setting your own UID/GID as a sysadmin.
- ⚠️ Language installation is not supported. Since this image is unprivileged, package installation with the default `docker-entrypoint.sh` will not be possible.

### Licensing
- Licensed under GPL 3 to comply with licensing changes by Paperless-ngx.
- Any image built by Polarix Containers is provided under the combination of license terms resulting from the use of individual packages.