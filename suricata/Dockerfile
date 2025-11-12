# =========================
# Stage 1: Build (builder)
# =========================
FROM debian:bookworm-slim AS builder

ARG SURICATA_BRANCH=suricata-8.0.2
ARG SURICATA_TAG=suricata-8.0.2
ARG NDPI_BRANCH=4.14-stable
ENV DEBIAN_FRONTEND=noninteractive

# Make binaries portable across CPUs
ENV COMMON_CFLAGS="-O2 -fPIC -pipe -march=x86-64 -mtune=generic"
ENV CFLAGS="${COMMON_CFLAGS}" CXXFLAGS="${COMMON_CFLAGS}"

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git ca-certificates curl wget \
    autoconf automake libtool pkg-config ragel \
    libpcap-dev libnet1-dev libyaml-dev libjansson-dev \
    libmagic-dev libcap-ng-dev libnetfilter-queue-dev libnfnetlink-dev \
    liblz4-dev libpcre2-dev zlib1g-dev libsystemd-dev \
    libhyperscan-dev python3 clang llvm \
 && rm -rf /var/lib/apt/lists/*

# Rust toolchain + cbindgen
RUN rustc --version 2>/dev/null | grep -q "1\.75\.0" || \
    (curl -sSf https://sh.rustup.rs | sh -s -- -y && \
     . "$HOME/.cargo/env" && rustup install 1.75.0 && rustup default 1.75.0)
ENV PATH="/root/.cargo/bin:${PATH}"
RUN . "$HOME/.cargo/env" && cargo +stable install --locked cbindgen

# ---------- Build nDPI (kept for Suricata plugin) ----------
RUN git clone --depth=1 --branch "${NDPI_BRANCH}" https://github.com/ntop/nDPI.git /opt/ndpi && \
    cd /opt/ndpi && \
    ./autogen.sh && \
    ./configure --disable-shared --enable-static && \
    make -j"$(nproc)"

RUN test -f /opt/ndpi/src/include/ndpi_api.h && test -f /opt/ndpi/src/lib/libndpi.a
RUN mkdir -p /ndpi-out && \
    cp -a /opt/ndpi/src/lib/libndpi.so* /ndpi-out/ 2>/dev/null || true && \
    cp -a /opt/ndpi/src/lib/libndpi.a   /ndpi-out/ 2>/dev/null || true

# ---------- Build Suricata ----------
RUN git clone --depth=1 --branch "${SURICATA_TAG}" https://github.com/OISF/suricata.git /build/suricata && \
    cd /build/suricata && \
    ./autogen.sh && \
    CPPFLAGS="-I/opt/ndpi/src/include" \
    LDFLAGS="-L/opt/ndpi/src/lib" \
    ./configure \
      --enable-plugins \
      --enable-nfqueue \
      --enable-ndpi --with-ndpi=/opt/ndpi \
      --disable-gccmarch-native \
      --prefix=/usr \
      --sysconfdir=/etc \
      --localstatedir=/var && \
    make -j"$(nproc)" && \
    make install-conf install && \
    ldconfig

# Strip Suricata binary and plugins
RUN strip --strip-unneeded /usr/bin/suricata || true && \
    find /usr/lib/suricata -type f -name '*.so' -exec strip --strip-unneeded {} + || true

# =========================
# Stage 2: Runtime
# =========================
FROM debian:bookworm-slim AS runtime
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      libpcap0.8 libnet1 libyaml-0-2 libjansson4 libmagic1 \
      libcap-ng0 libnetfilter-queue1 libnfnetlink0 liblz4-1 \
      libpcre2-8-0 zlib1g libsystemd0 libhyperscan5 \
      ca-certificates tini suricata-update python3 python3-yaml \
   && rm -rf /var/lib/apt/lists/*

# Core Suricata artifacts
COPY --from=builder /usr/bin/suricata      /usr/bin/suricata
COPY --from=builder /usr/bin/suricata*     /usr/bin/
COPY --from=builder /usr/lib/suricata      /usr/lib/suricata
COPY --from=builder /usr/share/suricata    /usr/share/suricata
COPY --from=builder /etc/suricata          /etc/suricata
COPY --from=builder /var/lib/suricata      /var/lib/suricata

# nDPI runtime libs (whatever was produced)
COPY --from=builder /ndpi-out/ /usr/lib/

# Runtime dirs
RUN mkdir -p /var/log/suricata /var/run/suricata

# Non-root
RUN useradd -r -u 990 -g nogroup suri && \
    chown -R suri:nogroup /var/log/suricata /var/run/suricata /var/lib/suricata

# Lightweight entrypoint (optional rules refresh)
COPY <<'SH' /usr/local/bin/entrypoint.sh
#!/bin/sh
set -e
if [ "${SURICATA_UPDATE_ON_START:-0}" = "1" ]; then
  suricata-update --no-test || echo "suricata-update failed (continuing)"
fi
exec "$@"
SH
RUN chmod +x /usr/local/bin/entrypoint.sh

HEALTHCHECK --interval=30s --timeout=10s --retries=5 \
  CMD sh -lc 'command -v suricatasc >/dev/null 2>&1 || exit 0; suricatasc -c uptime >/dev/null 2>&1 || exit 1'

ARG SURICATA_BRANCH
LABEL org.opencontainers.image.title="Suricata (nDPI + Hyperscan)" \
      org.opencontainers.image.vendor="carterfields" \
      org.opencontainers.image.version="${SURICATA_BRANCH}" \
      org.opencontainers.image.source="https://github.com/OISF/suricata"

ENTRYPOINT ["tini","--","/usr/local/bin/entrypoint.sh"]
USER suri
CMD ["suricata","-c","/etc/suricata/suricata.yaml","-i","eth0","--init-errors-fatal"]
