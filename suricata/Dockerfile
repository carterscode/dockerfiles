# =========================================================
# Stage 1: Build Suricata (with nDPI + Hyperscan), strip
# =========================================================
FROM debian:bookworm-slim AS builder

ARG SURICATA_BRANCH=v8.0.2
ARG NDPI_BRANCH=4.14-stable  # pick a stable nDPI tag you trust
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /build

# Base build deps

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git ca-certificates curl wget \
    autoconf automake libtool pkg-config ragel \
    libpcap-dev libnet1-dev libyaml-dev libjansson-dev \
    libmagic-dev libcap-ng-dev libnetfilter-queue-dev libnfnetlink-dev \
    liblz4-dev libpcre2-dev zlib1g-dev libsystemd-dev \
    libhyperscan-dev \
    python3 \
    clang llvm \
 && rm -rf /var/lib/apt/lists/*
 

# Rust (for Suricata’s Rust modules)
RUN rustc --version 2>/dev/null | grep -q "1\.75\.0" || \
    (curl -sSf https://sh.rustup.rs | sh -s -- -y && \
     . "$HOME/.cargo/env" && \
     rustup install 1.75.0 && rustup default 1.75.0)
ENV PATH="/root/.cargo/bin:$PATH"

# cbindgen for Rust<->C header generation
RUN . "$HOME/.cargo/env" && cargo +stable install --locked cbindgen

# -------- Build nDPI (shared lib) --------
RUN git clone --depth=1 --branch "${NDPI_BRANCH}" https://github.com/ntop/nDPI.git && \
    cd nDPI && \
    ./autogen.sh && \
    ./configure --prefix=/usr && \
    make -j"$(nproc)" && \
    echo $PWD && \
    make install

# -------- Build Suricata --------
# --- Clone, build, and install Suricata 8.0.2 (pinned tag) ---
ARG SURICATA_TAG=suricata-8.0.2
RUN git clone --depth=1 --branch "${SURICATA_TAG}" https://github.com/OISF/suricata.git && \
    cd suricata && \
    ./autogen.sh && \
    ./configure \
      --enable-nfqueue \
      --enable-ndpi --with-ndpi=/build/suricata/plugins/ndpi \
      # --enable-rust \
      # --with-hyperscan \
      --prefix=/usr \
      --sysconfdir=/etc \
      --localstatedir=/var && \
    make -j"$(nproc)" && \
    make install-full && \
    ldconfig

# Strip Suricata binary and plugins to shrink size
# (safe to strip; removes debug symbols)
RUN strip --strip-unneeded /usr/bin/suricata || true && \
    find /usr/lib/suricata -type f -name '*.so' -exec strip --strip-unneeded {} + || true

# =========================================================
# Stage 2: Runtime (small & secure)
# =========================================================
FROM debian:bookworm-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive

# Minimal runtime libs + tini (PID 1) + suricata-update + CA bundle
RUN apt-get update && apt-get install -y --no-install-recommends \
      libpcap0.8 \
      libnet1 \
      libyaml-0-2 \
      libjansson4 \
      libmagic1 \
      libcap-ng0 \
      libnetfilter-queue1 \
      libnfnetlink0 \
      liblz4-1 \
      libpcre2-8-0 \
      zlib1g \
      libsystemd0 \
      libhyperscan5 \
      ca-certificates \
      tini \
      suricata-update \
      python3 python3-yaml \
   && rm -rf /var/lib/apt/lists/*

# Copy ONLY Suricata artifacts; do NOT overwrite system libs
COPY --from=builder /usr/bin/suricata      /usr/bin/suricata
COPY --from=builder /usr/bin/suricata*     /usr/bin/
COPY --from=builder /usr/lib/suricata      /usr/lib/suricata
COPY --from=builder /usr/share/suricata    /usr/share/suricata
COPY --from=builder /etc/suricata          /etc/suricata
COPY --from=builder /var/lib/suricata      /var/lib/suricata

# Prepare runtime dirs
RUN mkdir -p /var/log/suricata /var/run/suricata

# ----- Security hardening: run as non-root -----
# Create unprivileged user, own writable paths
RUN useradd -r -u 990 -g nogroup suri && \
    chown -R suri:nogroup /var/log/suricata /var/run/suricata /var/lib/suricata

# Optional: file capabilities (lets you avoid cap_add in compose)
# If you prefer docker-compose cap_add, you can skip this.
# RUN apt-get update && apt-get install -y --no-install-recommends libcap2-bin && rm -rf /var/lib/apt/lists/* && \
#     setcap 'cap_net_admin,cap_net_raw+eip' /usr/bin/suricata

# Small, optional entrypoint that can refresh rules on start when requested
# (keeps default behavior unchanged)
COPY <<'SH' /usr/local/bin/entrypoint.sh
#!/bin/sh
set -e
# Optional one-shot rules refresh
if [ "${SURICATA_UPDATE_ON_START:-0}" = "1" ]; then
  suricata-update --no-test || echo "suricata-update failed (continuing)"
fi
exec "$@"
SH
RUN chmod +x /usr/local/bin/entrypoint.sh

# Healthcheck via Suricata command socket (enable unix-command in your config)
# Falls back harmlessly if socket isn't ready yet.
HEALTHCHECK --interval=30s --timeout=10s --retries=5 \
  CMD sh -lc 'command -v suricatasc >/dev/null 2>&1 || exit 0; suricatasc -c uptime >/dev/null 2>&1 || exit 1'

# OCI labels for traceability
ARG SURICATA_BRANCH
LABEL org.opencontainers.image.title="Suricata (nDPI + Hyperscan)" \
      org.opencontainers.image.vendor="carterfields" \
      org.opencontainers.image.version="${SURICATA_BRANCH}" \
      org.opencontainers.image.source="https://github.com/OISF/suricata"

# Use tini as PID 1, then our wrapper
ENTRYPOINT ["tini","--","/usr/local/bin/entrypoint.sh"]

# Drop privileges
USER suri

# Default command (interface can be overridden at runtime)
CMD ["suricata","-c","/etc/suricata/suricata.yaml","-i","eth0","--init-errors-fatal"]
