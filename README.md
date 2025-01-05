# Paperless-ngx

![Build, scan & push](https://github.com/Polarix-Containers/paperless-ngx/actions/workflows/build.yml/badge.svg)

### Features & usage
- Drop-in replacement for the [official image](https://github.com/paperless-ngx/paperless-ngx).
- ⚠️ Unprivileged image. Due to how `entrypoint.sh` is coded upstream, you must use 200005 as the UID/GID. Make sure the mountpoints are owned by the same user.

### Licensing
- Licensed under GPL 3 to comply with licensing changes by Paperless-ngx.
- Any image built by Polarix Containers is provided under the combination of license terms resulting from the use of individual packages.
