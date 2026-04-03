# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE_REGISTRY=ghcr.io
ARG BASE_IMAGE_NAME=linuxserver/baseimage-alpine
ARG BASE_IMAGE_VARIANT=3.22
ARG BASE_IMAGE=${BASE_IMAGE_REGISTRY}/${BASE_IMAGE_NAME}:${BASE_IMAGE_VARIANT}
ARG READSB_REPO_URL=https://github.com/wiedehopf/readsb
ARG READSB_REPO_BRANCH=dev

FROM ${BASE_IMAGE} AS builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG READSB_REPO_URL
ARG READSB_REPO_BRANCH

RUN apk add --no-cache \
        build-base \
        git \
        pkgconf \
        zlib-dev \
        zstd-dev

WORKDIR /src
RUN git clone --branch ${READSB_REPO_BRANCH} --single-branch --depth 1 ${READSB_REPO_URL} . && \
    rm -rf .git

# Build only the readsb binary, no interactive TUI, no SDR drivers
RUN set -e && \
    MARCH="" && \
    if [ "$(uname -m)" = "x86_64" ]; then MARCH=" -march=nehalem"; fi && \
    make -j"$(nproc)" readsb DISABLE_INTERACTIVE=yes OPTIMIZE="-O2${MARCH}" && \
    strip --strip-unneeded readsb

FROM ${BASE_IMAGE}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

LABEL maintainer="Blackout Secure - https://blackoutsecure.app/"
LABEL org.opencontainers.image.title="docker-mlat-hub" \
    org.opencontainers.image.description="LinuxServer.io containerized MLAT hub aggregating readsb network-only feeds into one combined Beast output." \
    org.opencontainers.image.url="https://github.com/blackoutsecure/docker-mlat-hub" \
    org.opencontainers.image.source="https://github.com/blackoutsecure/docker-mlat-hub" \
    org.opencontainers.image.licenses="GPL-3.0-or-later"

RUN apk add --no-cache zlib zstd-libs

COPY --link --from=builder /src/readsb /usr/local/bin/readsb
COPY --link root/ /

ENV MLATHUB_RUN_DIR="/run/mlathub"

EXPOSE 30104 30105

RUN find /etc/s6-overlay/s6-rc.d -type f \( -name run -o -name finish -o -name check \) -exec chmod 0755 {} + && \
    # Disable base image services not needed by this container:
    # - svc-cron: no cron jobs; if crontabs exist from base image, crond starts and fills logs
    # - init-crontab-config: sets up crontabs that would trigger svc-cron
    rm -f /etc/s6-overlay/s6-rc.d/user/contents.d/svc-cron \
          /etc/s6-overlay/s6-rc.d/user/contents.d/init-crontab-config && \
    rm -rf /tmp/* /var/tmp/* /var/cache/apk/*

# Health check: verify readsb process is listening on beast output port
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD ["/bin/bash", "-c", \
    "netstat -tln 2>/dev/null | grep -q ':30105 ' || ss -tln | grep -q ':30105 '"]
