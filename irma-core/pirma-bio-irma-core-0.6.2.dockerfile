ARG BASE_IMAGE=025066257930.dkr.ecr.us-east-1.amazonaws.com/oamd-bio-base-ubuntu@sha256:96fa78a49cf6325e61b8820ea227ca85fcf3380b5a11674b2c02e7846312c718

# ---

FROM $BASE_IMAGE AS builder

ARG IRMA_CORE_VER=0.6.2

RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
 && apt-get update \
 && apt-get -y --no-install-recommends install \
      ca-certificates \
      curl

WORKDIR /build

RUN curl -sL https://github.com/CDCgov/irma-core/releases/download/v${IRMA_CORE_VER}/irma-core-linux-x86_64-v${IRMA_CORE_VER}.tar.gz \
      | tar xz \
 && chmod 755 irma-core

# ---

FROM $BASE_IMAGE AS final

COPY --from=builder /build/irma-core /usr/local/bin/

USER default
