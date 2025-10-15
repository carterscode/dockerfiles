# Stage 1: Build Suricata with dependencies
FROM debian:bookworm-slim AS builder

WORKDIR /build

# Build arguments
ARG SURICATA_BRANCH=main

# Install base dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    autoconf \
    automake \
    libtool \
    pkg-config \
    libpcap-dev \
    libnet1-dev \
    libyaml-dev \
    libjansson-dev \
    libmagic-dev \
    libcap-ng-dev \
    libnetfilter-queue-dev \
    libnfnetlink-dev \
    liblz4-dev \
    libpcre2-dev \
    zlib1g-dev \
    python3 \
    wget \
    curl \
    clang \
    llvm \
    ca-certificates \
    libsystemd-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Rust 1.75.0 if not already present
RUN rustc --version | grep -q "1.75.0" || \
    (curl https://sh.rustup.rs -sSf | sh -s -- -y && \
    . $HOME/.cargo/env && \
    rustup install 1.75.0 && \
    rustup default 1.75.0)

ENV PATH="/root/.cargo/bin:$PATH"

# Install cbindgen (required for building Suricata with Rust)
RUN cargo install --force cbindgen

# Build and install nDPI
RUN git clone https://github.com/ntop/nDPI.git && \
    cd nDPI && \
    ./autogen.sh && \
    ./configure --prefix=/usr && \
    make -j"$(nproc)" && \
    make install

# Clone, build, and install Suricata 8.x
RUN git clone --branch ${SURICATA_BRANCH} https://github.com/OISF/suricata.git && \
    cd suricata && \
    ./autogen.sh && \
    ./configure \
        --enable-nfqueue \
        --enable-ndpi \
        --enable-rust \
        --prefix=/usr \
        --sysconfdir=/etc \
        --localstatedir=/var && \
    make -j"$(nproc)" && \
    make install-full && \
    ldconfig

# Stage 2: Runtime image
FROM debian:bookworm-slim AS runtime

# Install minimal runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
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
    && rm -rf /var/lib/apt/lists/*

# Copy built Suricata files from builder stage
COPY --from=builder /usr/bin/suricata /usr/bin/suricata
COPY --from=builder /usr/lib /usr/lib
# Platform-specific copy: only for x86_64 builds
COPY --from=builder --platform=linux/amd64 /usr/lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu
COPY --from=builder /usr/lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu
COPY --from=builder /etc/suricata /etc/suricata
COPY --from=builder /var/lib/suricata /var/lib/suricata
COPY --from=builder /usr/share/suricata /usr/share/suricata

# Create Suricata runtime directories
RUN mkdir -p /var/log/suricata /var/run/suricata

# Copy custom entrypoint if needed (optional)
# COPY entrypoint.sh /entrypoint.sh
# RUN chmod +x /entrypoint.sh

# Default command
CMD ["suricata", "-c", "/etc/suricata/suricata.yaml", "-i", "eth0", "--init-errors-fatal"]
#test
#test2
