ARG BASE_IMAGE=025066257930.dkr.ecr.us-east-1.amazonaws.com/oamd-bio-base-ubuntu@sha256:96fa78a49cf6325e61b8820ea227ca85fcf3380b5a11674b2c02e7846312c718

ARG IRMA_VER=1.3.1

# ---

FROM $BASE_IMAGE AS builder

ARG IRMA_VER

RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
 && apt-get update \
 && apt-get -y --no-install-recommends install \
      ca-certificates \
      curl \
      unzip

WORKDIR /build
RUN curl -fsSL -o irma.zip "https://github.com/CDCgov/irma/releases/download/v${IRMA_VER}/irma-v${IRMA_VER}-universal.zip" \
 && unzip -q irma.zip \
 && rm irma.zip \
 && mv flu-amd /irma

# ---

FROM $BASE_IMAGE AS final

COPY --from=builder /irma /irma

RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
 && apt-get update \
 && apt-get -y --no-install-recommends install \
      perl \
      r-base-core \
      zip

# Symlink all bundled x86_64 binaries onto PATH for Nextflow process access
RUN ln -s /irma/IRMA_RES/scripts/irma-core_Linux_x86_64 /usr/local/bin/irma-core \
 && ln -s /irma/IRMA_RES/third_party/blat_Linux_x86_64 /usr/local/bin/blat \
 && ln -s /irma/IRMA_RES/third_party/ssw_Linux_x86_64 /usr/local/bin/ssw \
 && ln -s /irma/IRMA_RES/third_party/minimap2_Linux_x86_64 /usr/local/bin/minimap2 \
 && ln -s /irma/IRMA_RES/third_party/pigz_Linux_x86_64 /usr/local/bin/pigz \
 && ln -s /irma/IRMA_RES/third_party/samtools_Linux_x86_64 /usr/local/bin/samtools \
 && ln -s /irma/LABEL_RES/third_party/align2model_Linux_x86_64 /usr/local/bin/align2model \
 && ln -s /irma/LABEL_RES/third_party/hmmscore_Linux_x86_64 /usr/local/bin/hmmscore \
 && ln -s /irma/LABEL_RES/third_party/modelfromalign_Linux_x86_64 /usr/local/bin/modelfromalign \
 && ln -s /irma/LABEL_RES/third_party/shogun_Linux_x86_64 /usr/local/bin/cmdline_static \
 && ln -s /irma/LABEL /usr/local/bin/LABEL

ENV PATH="/irma:${PATH}"

USER default
