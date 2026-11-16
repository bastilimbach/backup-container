# syntax=docker/dockerfile:1
FROM alpine:3.24

LABEL org.opencontainers.image.title="backup-container" \
      org.opencontainers.image.description="mbsync, vdirsyncer and pimsync bundled for scheduled mail/contacts/calendar backups" \
      org.opencontainers.image.source="https://github.com/bastilimbach/backup-container" \
      org.opencontainers.image.documentation="https://github.com/bastilimbach/backup-container#readme" \
      org.opencontainers.image.licenses="MIT"

# Pinned tool versions
ARG ISYNC_VERSION=1.5.1-r1
ARG VDIRSYNCER_VERSION=0.20.0-r2
ARG PIMSYNC_VERSION=0.7.0-r0

# Add edge repository
RUN echo "@edge https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories

RUN apk add --no-cache \
        isync=${ISYNC_VERSION} \
        vdirsyncer=${VDIRSYNCER_VERSION} \
        pimsync@edge=${PIMSYNC_VERSION} \
        ca-certificates \
        tzdata

ENV HOME=/config \
    XDG_CONFIG_HOME=/config/.config \
    XDG_DATA_HOME=/data

CMD ["sh", "-c", "echo 'Pass a command, e.g.: mbsync -a | vdirsyncer sync | pimsync sync'"]
