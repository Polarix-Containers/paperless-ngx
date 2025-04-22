# Paperless-ngx

![Build, scan & push](https://github.com/Polarix-Containers/paperless-ngx/actions/workflows/build.yml/badge.svg)

⚠️ Version 2.14.7 is temporarily pinned until the container can be updated to the new setup with s6.

### Features & usage
- Drop-in replacement for the [official image](https://github.com/paperless-ngx/paperless-ngx).
- Added `tesseract-ocr-data-osd`.
- ⚠️ Unprivileged image. Due to how various scripts are coded upstream, you must use 200005 as the UID/GID. Make sure the mountpoints are owned by the same user.
- ⚠️ Only English is supported. Since this image is unprivileged, package installation with the default `docker-entrypoint.sh` will not be possible.

### Licensing
- Licensed under GPL 3 to comply with licensing changes by Paperless-ngx.
- Any image built by Polarix Containers is provided under the combination of license terms resulting from the use of individual packages.