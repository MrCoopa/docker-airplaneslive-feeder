# ========================================================
# airplanes.live ADS-B & MLAT Feeder Container
# Base: Alpine Linux (Ultra-lightweight ~25 MB)
# ========================================================

# --- Stage 1: Build Stage ---
FROM alpine:latest AS builder

RUN apk add --no-cache \
    build-base \
    pkgconf \
    git \
    python3 \
    python3-dev \
    py3-setuptools \
    py3-pip \
    ncurses-dev \
    zlib-dev \
    zstd-dev

# Install pyasyncore for Python 3.12+ backward compatibility required by mlat-client
RUN pip install --no-cache-dir --break-system-packages --root=/src/mlat-install pyasyncore

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
FROM alpine:latest

RUN apk add --no-cache \
    python3 \
    bash \
    curl \
    ca-certificates \
    ncurses-libs \
    zlib \
    zstd-libs \
    procps && \
    rm -rf /var/cache/apk/*

# Copy binaries and installed python packages
COPY --from=builder /src/readsb-src/readsb /usr/local/bin/readsb
COPY --from=builder /src/mlat-install/ /

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /usr/local/bin/readsb && \
    mkdir -p /var/lib/airplaneslive

VOLUME ["/var/lib/airplaneslive"]

ENTRYPOINT ["/entrypoint.sh"]
