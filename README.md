# ✈️ docker-airplaneslive

[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg?logo=docker)](https://www.docker.com/)
[![Alpine](https://img.shields.io/badge/Alpine-Linux-0D597F.svg?logo=alpinelinux&logoColor=white)](https://alpinelinux.org/)
[![airplanes.live](https://img.shields.io/badge/Feed-airplanes.live-orange.svg)](https://airplanes.live)

Lightweight, modern Docker container to feed ADS-B and MLAT (Multilateration) data to [airplanes.live](https://airplanes.live/) with full support for **local MLAT return feed** into your own receiver map (e.g. `tar1090` / `dump1090` / `readsb`).

---

## 🚀 Features

* **Ultra-Lightweight Base:** Built on top of **Alpine Linux** (~25 MB image size) using a clean multi-stage build.
* **Low Bandwidth:** Uses high-performance `readsb` net-connector with `beast_reduce_plus_out` to stream Beast packets efficiently.
* **Native MLAT (Multilateration):** Runs `mlat-client` to synchronize Mode-S reception times with `feed.airplanes.live:31090`.
* **Live MLAT Return Feed:** Feeds calculated MLAT positions straight back into your local decoder (e.g. port `30004`), displaying MLAT planes on your local `tar1090` map!
* **Persistent Station UUID:** Automatically generates and stores a persistent feeder UUID in `/var/lib/airplaneslive/uuid` across container restarts.
* **Configurable via Environment:** Easy setup with standard `.env` variables.

---

## 📦 Quick Start with Docker Compose

### 1. Standalone Setup (e.g. in `/opt/airplaneslive`)

Clone this repository and start the container in its own directory:

```bash
git clone https://github.com/MrCoopa/docker-airplaneslive-feeder.git /opt/airplaneslive
cd /opt/airplaneslive
```

`docker-compose.yml`:
```yaml
services:
  airplaneslive:
    build: .
    image: airplaneslive-feeder:latest
    container_name: airplaneslive-feeder
    restart: unless-stopped
    network_mode: host
    environment:
      - BEAST_HOST=127.0.0.1
      - BEAST_PORT=30005
      - LAT=50.1234
      - LON=8.1234
      - ALT=150m
      - USER=My-Station-Name
      - ENABLE_MLAT=true
      - MLAT_RESULTS_HOST=127.0.0.1
      - MLAT_RESULTS_PORT=30004
    volumes:
      - airplaneslive-data:/var/lib/airplaneslive

volumes:
  airplaneslive-data:
```

### 2. Sidecar Setup (Inside existing `docker-compose.yml`)

You can also run it directly inside your existing ADS-B compose file:

```yaml
  airplaneslive:
    build: https://github.com/MrCoopa/docker-airplaneslive-feeder.git#main
    container_name: airplaneslive-feeder
    restart: unless-stopped
    depends_on:
      - dump1090
    environment:
      - BEAST_HOST=dump1090
      - BEAST_PORT=30005
      - LAT=50.1234
      - LON=8.1234
      - ALT=150m
      - USER=My-Station-Name
      - ENABLE_MLAT=true
      - MLAT_RESULTS_HOST=dump1090
      - MLAT_RESULTS_PORT=30004
    volumes:
      - airplaneslive-data:/var/lib/airplaneslive
```

### 2. Start the Feeder

```bash
docker compose up -d --build
```

### 3. Check Feeder Logs

```bash
docker compose logs -f airplaneslive
```

---

## ⚙️ Environment Variables

| Variable | Default | Description |
| :--- | :--- | :--- |
| `BEAST_HOST` | `dump1090` | Hostname or IP of the Beast binary stream source |
| `BEAST_PORT` | `30005` | TCP port of the Beast source |
| `FEED_SERVER` | `feed.airplanes.live:30004` | Destination ADS-B server |
| `MLAT_SERVER` | `feed.airplanes.live:31090` | Destination MLAT server |
| `LAT` | - | **Required for MLAT:** Antenna latitude (e.g. `50.12345`) |
| `LON` | - | **Required for MLAT:** Antenna longitude (e.g. `8.12345`) |
| `ALT` | `0m` | **Required for MLAT:** Antenna altitude with unit (e.g. `180m` or `590ft`) |
| `USER` / `SITE_NAME` | `AirplanesLive-Feeder` | Station display name on airplanes.live |
| `ENABLE_MLAT` | `true` | Enable or disable MLAT client (`true` or `false`) |
| `MLAT_RESULTS_HOST` | `$BEAST_HOST` | Target host for MLAT return feed |
| `MLAT_RESULTS_PORT` | `30004` | Target Beast input port for MLAT return feed |
| `UUID` | - | Optional manual station UUID (otherwise auto-generated) |

---

## 🌐 Verifying Your Feed

1. Visit [airplanes.live/stations/](https://airplanes.live/stations/) and search for your `USER` / `SITE_NAME`.
2. Check your local `tar1090` web interface: Non-ADS-B aircraft located by Multilateration will show `mlat` in the data source column!

---

## 🇩🇪 Deutsche Kurzanleitung

1. **Koordinaten ermitteln:** Ermittle deine genauen Antennenkoordinaten (`LAT`, `LON`) und die Höhe über Normalhöhennull (`ALT`, z. B. `180m`).
2. **In Docker Compose einbinden:** Trage den Service in deine `docker-compose.yml` ein.
3. **Starten:** `docker compose up -d --build` ausführen.
4. **Prüfen:** Mit `docker compose logs -f airplaneslive` die Verbindung überwachen. Innerhalb von Sekunden streamt dein Empfänger Flugzeuge zu airplanes.live und empfängt MLAT-Positionen zurück!
