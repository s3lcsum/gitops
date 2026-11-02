# Alpine CI image. tofu/terragrunt linux_amd64 need gcompat (glibc on musl). WireGuard: NET_ADMIN + /dev/net/tun.
ARG TOFU_VERSION=1.12.5
ARG TG_VERSION=1.2.1

FROM alpine:3.21 AS fetch
ARG TOFU_VERSION
ARG TG_VERSION
RUN set -eux; \
    apk add --no-cache ca-certificates curl unzip; \
    mkdir -p /out; \
    curl -fsSL "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_amd64.zip" -o /tmp/tofu.zip; \
    unzip -p /tmp/tofu.zip tofu > /out/tofu; \
    curl -fsSL "https://github.com/gruntwork-io/terragrunt/releases/download/v${TG_VERSION}/terragrunt_linux_amd64" -o /out/terragrunt; \
    chmod +x /out/tofu /out/terragrunt; \
    rm -f /tmp/tofu.zip

FROM alpine:3.21

RUN set -eux; \
    apk add --no-cache \
      bash ca-certificates curl jq git make iproute2 wireguard-tools gcompat

COPY --from=fetch /out/tofu /usr/local/bin/tofu
COPY --from=fetch /out/terragrunt /usr/local/bin/terragrunt

RUN tofu version && terragrunt --version

WORKDIR /build
