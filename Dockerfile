#
# Builder image
#
FROM golang:1.19.5-alpine3.17 AS builder

ARG RESTIC_VERSION=0.15.0
ARG RESTIC_SHA256_AMD64=a1fccf26ba0a2f7ae387b9e639c8e87885ac5fca39e9eb3a24d7386d296252c2
ARG RESTIC_SHA256_ARM=53774723cd9aa6a4a815ad002dd8be8535611237463240767ef3821f0d9e14b4
ARG RESTIC_SHA256_ARM64=7e58ac2436868f98276bb647edeb7cae2c5cb68a9d4d4aa152b0c80985a72a3a

ARG RCLONE_VERSION=1.61.1
# These are the checksums for the zip files
ARG RCLONE_SHA256_AMD64=6d6455e1cb69eb0615a52cc046a296395e44d50c0f32627ba8590c677ddf50a9
ARG RCLONE_SHA256_ARM=00d485a13e0db43cacbb8a66316906b18356c8e0aed5821d7d26f077943f431e
ARG RCLONE_SHA256_ARM64=fff35786bf9ee9320037db69e239df83768b8f756bae2343253ba6512e70d86c

ARG GO_CRON_VERSION=0.0.4
ARG GO_CRON_SHA256=6c8ac52637150e9c7ee88f43e29e158e96470a3aaa3fcf47fd33771a8a76d959

RUN apk add --no-cache curl

RUN case "$(uname -m)" in \
  x86_64 ) \
    echo amd64 >/tmp/ARCH \
    ;; \
  armv7l) \
    echo arm >/tmp/ARCH \
    ;; \
  aarch64) \
    echo arm64 >/tmp/ARCH \
    ;; \
  esac

RUN case "$(cat /tmp/ARCH)" in \
  amd64 ) \
    echo "${RESTIC_SHA256_AMD64}" > RESTIC_SHA256 ; \
    echo "${RCLONE_SHA256_AMD64}" > RCLONE_SHA256 ; \
    ;; \
  arm ) \
    echo "${RESTIC_SHA256_ARM}" > RESTIC_SHA256 ; \
    echo "${RCLONE_SHA256_ARM}" > RCLONE_SHA256 ; \
    ;; \
  arm64 ) \
    echo "${RESTIC_SHA256_ARM64}" > RESTIC_SHA256 ; \
    echo "${RCLONE_SHA256_ARM64}" > RCLONE_SHA256 ; \
    ;; \
  *) \
    echo "unknown architecture '$(cat /tmp/ARCH)'" ; \
    exit 1 ; \
    ;; \
 esac

RUN curl -sL --fail -o restic.bz2 https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_linux_$(cat /tmp/ARCH).bz2 \
 && echo "$(cat RESTIC_SHA256)  restic.bz2" | sha256sum -c - \
 && bzip2 -d -v restic.bz2 \
 && mv restic /usr/local/bin/restic \
 && chmod +x /usr/local/bin/restic

 RUN curl -sL --fail -o rclone.zip https://github.com/rclone/rclone/releases/download/v${RCLONE_VERSION}/rclone-v${RCLONE_VERSION}-linux-$(cat /tmp/ARCH).zip \
 && echo "$(cat RCLONE_SHA256)  rclone.zip" | sha256sum -c - \
 && unzip rclone.zip \
 && mv rclone-v${RCLONE_VERSION}-linux-$(cat /tmp/ARCH)/rclone /usr/local/bin/rclone \
 && chmod +x /usr/local/bin/rclone \
 && rm -rf rclone-v${RCLONE_VERSION}-linux-$(cat /tmp/ARCH) \
 && rm rclone.zip

RUN curl -sL -o go-cron.tar.gz https://github.com/djmaze/go-cron/archive/v${GO_CRON_VERSION}.tar.gz \
 && echo "${GO_CRON_SHA256}  go-cron.tar.gz" | sha256sum -c - \
 && tar xzf go-cron.tar.gz \
 && cd go-cron-${GO_CRON_VERSION} \
 && go build \
 && mv go-cron /usr/local/bin/go-cron \
 && cd .. \
 && rm go-cron.tar.gz go-cron-${GO_CRON_VERSION} -fR


#
# Final image
#
FROM alpine:3.17

RUN apk add --update --no-cache ca-certificates coreutils fuse nfs-utils openssh tzdata bash curl docker-cli gzip tini

ENV RESTIC_REPOSITORY /mnt/restic
ENV MULTIREPO_CONFIG_PATH /run/secrets/repositories.conf

COPY --from=builder /usr/local/bin/* /usr/local/bin/
COPY archive backup prune check repo_wrapper functions /usr/local/bin/
COPY entrypoint /

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint"]
