#!/bin/bash
set -e

echo "========================================================"
echo "    airplanes.live ADS-B & MLAT Feeder (Docker)         "
echo "========================================================"

# Trap signals for graceful shutdown
cleanup() {
    echo "[airplanes-feeder] Stopping feeder processes..."
    pkill -P $$ || true
    exit 0
}
trap cleanup SIGTERM SIGINT SIGHUP SIGQUIT

# Configuration Variables
BEAST_HOST="${BEAST_HOST:-dump1090}"
BEAST_PORT="${BEAST_PORT:-30005}"
FEED_SERVER="${FEED_SERVER:-feed.airplanes.live:30004}"
MLAT_SERVER="${MLAT_SERVER:-feed.airplanes.live:31090}"
MLAT_RESULTS_HOST="${MLAT_RESULTS_HOST:-$BEAST_HOST}"
MLAT_RESULTS_PORT="${MLAT_RESULTS_PORT:-30004}"
ENABLE_MLAT="${ENABLE_MLAT:-true}"

USER_NAME="${USER:-${SITE_NAME:-AirplanesLive-Feeder}}"
LAT="${LAT:-${LATITUDE}}"
LON="${LON:-${LONGITUDE}}"
ALT="${ALT:-${ALTITUDE:-0m}}"

# Ensure persistent storage directory exists
mkdir -p /var/lib/airplaneslive

# Manage Persistent Feeder UUID
UUID_FILE="/var/lib/airplaneslive/uuid"
if [ -n "$UUID" ]; then
    echo "$UUID" > "$UUID_FILE"
elif [ -f "$UUID_FILE" ]; then
    UUID=$(cat "$UUID_FILE")
else
    # Generate new random UUID via python
    UUID=$(python3 -c "import uuid; print(str(uuid.uuid4()))")
    echo "$UUID" > "$UUID_FILE"
    echo "[airplanes-feeder] Generated new persistent station UUID: $UUID"
fi
echo "[airplanes-feeder] Using Station UUID: $UUID"
echo "[airplanes-feeder] Feeder Display Name: $USER_NAME"

# Parse Feed Server Host and Port
FEED_HOST=$(echo "$FEED_SERVER" | cut -d: -f1)
FEED_PORT=$(echo "$FEED_SERVER" | cut -d: -f2)

# Wait for local Beast source to become available
echo "[airplanes-feeder] Waiting for Beast data source at ${BEAST_HOST}:${BEAST_PORT}..."
while ! nc -z "$BEAST_HOST" "$BEAST_PORT" 2>/dev/null; do
    sleep 2
done
echo "[airplanes-feeder] Connected to Beast source (${BEAST_HOST}:${BEAST_PORT})!"

# 1. Start Beast Forwarder to airplanes.live
echo "[airplanes-feeder] Starting Beast forwarder to ${FEED_HOST}:${FEED_PORT} (protocol: beast_reduce_plus_out)..."
/usr/local/bin/readsb \
    --net --net-only --quiet \
    --net-connector "${BEAST_HOST},${BEAST_PORT},beast_in" \
    --net-connector "${FEED_HOST},${FEED_PORT},beast_reduce_plus_out,uuid=${UUID}" &
FORWARDER_PID=$!

# 2. Start MLAT Client if enabled and coordinates are present
MLAT_PID=""
if [ "$ENABLE_MLAT" = "true" ] || [ "$ENABLE_MLAT" = "1" ]; then
    if [ -n "$LAT" ] && [ -n "$LON" ] && [ "$LAT" != "0" ] && [ "$LON" != "0" ]; then
        echo "[airplanes-feeder] Starting MLAT client for ${MLAT_SERVER}..."
        echo "[airplanes-feeder] Receiver location: LAT=${LAT}, LON=${LON}, ALT=${ALT}"
        echo "[airplanes-feeder] MLAT return feed destination: ${MLAT_RESULTS_HOST}:${MLAT_RESULTS_PORT}"

        /usr/local/bin/mlat-client \
            --input-type dump1090 \
            --input-connect "${BEAST_HOST}:${BEAST_PORT}" \
            --server "${MLAT_SERVER}" \
            --user "${USER_NAME}" \
            --lat "${LAT}" \
            --lon "${LON}" \
            --alt "${ALT}" \
            --results "beast,connect,${MLAT_RESULTS_HOST}:${MLAT_RESULTS_PORT}" &
        MLAT_PID=$!
    else
        echo "[airplanes-feeder] WARNING: LAT and LON must be set to enable MLAT! Skipping MLAT."
    fi
else
    echo "[airplanes-feeder] MLAT is disabled (ENABLE_MLAT=false)."
fi

# Keep container alive and monitor processes
if [ -n "$MLAT_PID" ]; then
    wait -n $FORWARDER_PID $MLAT_PID || true
else
    wait $FORWARDER_PID || true
fi
