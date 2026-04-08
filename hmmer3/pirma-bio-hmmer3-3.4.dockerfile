ARG BASE_IMAGE=025066257930.dkr.ecr.us-east-1.amazonaws.com/oamd-bio-base-ubuntu@sha256:96fa78a49cf6325e61b8820ea227ca85fcf3380b5a11674b2c02e7846312c718

ARG HMMER_VER=3.4

# ---

FROM $BASE_IMAGE AS builder

ARG HMMER_VER

RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
 && apt-get update \
 && apt-get -y --no-install-recommends install \
      build-essential \
      ca-certificates \
      curl

WORKDIR /build

RUN curl -fsSL "http://eddylab.org/software/hmmer/hmmer-${HMMER_VER}.tar.gz" \
      | tar xz --strip-components=1 \
 && ./configure --prefix=/opt/hmmer \
 && make -j$(nproc) \
 && make install

# ---

FROM $BASE_IMAGE AS final

COPY --from=builder /opt/hmmer/bin/ /usr/local/bin/

USER default
