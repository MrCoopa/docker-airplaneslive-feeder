# ========================================================
# airplanes.live ADS-B & MLAT Feeder Container
# Base: Debian 13 (Trixie) Slim
# ========================================================

# --- Stage 1: Build Stage ---
FROM debian:trixie-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    pkg-config \
    python3 \
    python3-dev \
    python3-setuptools \
    libncurses-dev \
    libzstd-dev \
    zlib1g-dev \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Build lightweight readsb (net-only forwarder with beast_reduce_plus_out)
RUN git clone --depth 1 https://github.com/wiedehopf/readsb.git /src/readsb-src && \
    cd /src/readsb-src && \
    make -j$(nproc) RTLSDR=no BLADERF=no HACKRF=no LIMESDR=no SOAPYSDR=no OPTIMIZE="-O3" readsb && \
    strip /src/readsb-src/readsb

# Build mlat-client
RUN git clone --depth 1 https://github.com/mutability/mlat-client.git /src/mlat-client && \
    cd /src/mlat-client && \
    python3 setup.py build && \
    python3 setup.py install --root=/src/mlat-install

# --- Stage 2: Minimal Runtime ---
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    netcat-openbsd \
    curl \
    ca-certificates \
    libncurses6 \
    libzstd1 \
    zlib1g \
    procps && \
    rm -rf /var/lib/apt/lists/*

# Copy binaries and installed python packages
COPY --from=builder /src/readsb-src/readsb /usr/local/bin/readsb
COPY --from=builder /src/mlat-install/ /

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /usr/local/bin/readsb && \
    mkdir -p /var/lib/airplaneslive

VOLUME ["/var/lib/airplaneslive"]

ENTRYPOINT ["/entrypoint.sh"]
