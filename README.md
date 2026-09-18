# ✈️ docker-airplaneslive

[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg?logo=docker)](https://www.docker.com/)
[![Alpine](https://img.shields.io/badge/Alpine-Linux-0D597F.svg?logo=alpinelinux&logoColor=white)](https://alpinelinux.org/)
[![airplanes.live](https://img.shields.io/badge/Feed-airplanes.live-orange.svg)](https://airplanes.live)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Languages / Sprachen:** [🇬🇧 English](#-english) • [🇩🇪 Deutsch](#-deutsch)

---

<a name="-english"></a>
# 🇬🇧 English

Ultra-lightweight, high-performance Docker container to feed ADS-B and MLAT (Multilateration) data to [airplanes.live](https://airplanes.live/) with full support for a **local MLAT return feed** back into your own receiver map (e.g. `tar1090` / `dump1090` / `readsb`).

---

## 🏗 Architecture & Data Flow

```
                     ┌─────────────────────────────────────────────────────────┐
                     │                   airplanes.live Cloud                  │
                     │  ┌─────────────────────────┐ ┌────────────────────────┐  │
                     │  │ Ingest Port :30004      │ │ MLAT Server Port :31090│  │
                     │  │ (Beast ADS-B Stream)    │ │ (Multilateration Sync) │  │
                     │  └───────────▲─────────────┘ └───────────▲────────────┘  │
                     └──────────────┼───────────────────────────┼──────────────┘
                                    │ (Beast Stream Out)        │ (Mode-S Sync)
                                    │                           ▼ (Calculated TDOA)
┌──────────────────────────────┐    │    ┌─────────────────────────────────────┐
│      dump1090 / readsb       │    │    │      airplaneslive Container        │
│   (RTL-SDR / SDR Receiver)   │    │    │                                     │
│                              │────┴───►│ • readsb (Beast Forwarder)          │
│ • Port :30005 (Beast Output) │         │ • mlat-client (MLAT Engine)         │
│ • Port :30004 (Beast Input)  │◄────────┤ • Persistent Station UUID           │
│                              │ (Return)└─────────────────────────────────────┘
│ • tar1090 Web Map (:8080)    │
│   (Shows local ADS-B + MLAT!)│
└──────────────────────────────┘
```

---

## 🚀 Features

* **Ultra-Lightweight Alpine Base:** Multi-stage build on top of **Alpine Linux** resulting in an image size of only ~25 MB with minimal CPU & RAM overhead.
* **Efficient Beast Forwarding:** Uses `readsb` net-connector with `beast_reduce_plus_out,uuid=...` to ensure low network bandwidth and proper aggregator accounting.
* **Native Multilateration (MLAT):** Integrated `mlat-client` synchronizing Mode-S timestamps with `feed.airplanes.live:31090`.
* **Live Local MLAT Return Feed:** Streams calculated MLAT positions directly back to your local receiver (e.g. `dump1090:30004`), allowing non-ADS-B aircraft to show up with an `MLAT` badge on your local `tar1090` map!
* **Automatic Persistent Station UUID:** Automatically generates a persistent UUID in `/var/lib/airplaneslive/uuid` preserved via a Docker volume across container updates.
* **Flexible Networking:** Built-in DNS detection automatically resolves container hostnames (e.g. `dump1090`) or falls back to `127.0.0.1` when running in Docker `host` network mode.

---

## 📦 Quick Start with Docker Compose

### Option A: Standalone Service (with existing ADS-B receiver)

```yaml
services:
  airplaneslive:
    image: ghcr.io/mrcoopa/airplaneslive-feeder:latest
    # Or build locally:
    # build: https://github.com/MrCoopa/docker-airplaneslive-feeder.git#main
    container_name: airplaneslive-feeder
    restart: unless-stopped
    environment:
      - BEAST_HOST=192.168.1.50   # IP of your ADS-B receiver
      - BEAST_PORT=30005
      - LAT=50.1234              # Your antenna latitude
      - LON=8.1234               # Your antenna longitude
      - ALT=150m                 # Your antenna altitude (m or ft)
      - USER=My-Station-Name     # Feeder display name
      - ENABLE_MLAT=true
      - MLAT_RESULTS_HOST=192.168.1.50
      - MLAT_RESULTS_PORT=30004  # Ingest port on local decoder
    volumes:
      - airplaneslive-data:/var/lib/airplaneslive

volumes:
  airplaneslive-data:
```

### Option B: Sidecar Service in Same Docker Compose

```yaml
services:
  dump1090:
    # Your primary receiver container...
    ports:
      - "8080:8080"
      - "30004:30004"   # Required for MLAT return feed
      - "30005:30005"   # Beast output

  airplaneslive:
    build: https://github.com/MrCoopa/docker-airplaneslive-feeder.git#main
    container_name: airplaneslive-feeder
    restart: unless-stopped
    depends_on:
      - dump1090
    environment:
      - BEAST_HOST=dump1090
      - BEAST_PORT=30005
      - LAT=${LAT:-50.1234}
      - LON=${LON:-8.1234}
      - ALT=${ALT:-150m}
      - USER=${SITE_NAME:-My-Station}
      - ENABLE_MLAT=true
      - MLAT_RESULTS_HOST=dump1090
      - MLAT_RESULTS_PORT=30004
    volumes:
      - airplaneslive-data:/var/lib/airplaneslive

volumes:
  airplaneslive-data:
```

---

## ⚙️ Environment Variables

| Variable | Default | Description |
| :--- | :--- | :--- |
| `BEAST_HOST` | `dump1090` | Hostname or IP of your Beast binary data source |
| `BEAST_PORT` | `30005` | TCP port of your Beast source |
| `FEED_SERVER` | `feed.airplanes.live:30004` | Destination ADS-B server and port |
| `MLAT_SERVER` | `feed.airplanes.live:31090` | Destination MLAT server and port |
| `LAT` | - | **Required for MLAT:** Antenna latitude (decimal degrees, e.g. `50.1234`) |
| `LON` | - | **Required for MLAT:** Antenna longitude (decimal degrees, e.g. `8.1234`) |
| `ALT` | `0m` | **Required for MLAT:** Antenna altitude with unit (e.g. `180m` or `590ft`) |
| `USER` / `SITE_NAME` | `AirplanesLive-Feeder` | Station display name on airplanes.live |
| `ENABLE_MLAT` | `true` | Enable or disable MLAT synchronization (`true` / `false`) |
| `MLAT_RESULTS_HOST` | `$BEAST_HOST` | Hostname/IP to send calculated MLAT fixes back to |
| `MLAT_RESULTS_PORT` | `30004` | Local Beast input port (usually `30004`) |
| `UUID` | - | Optional manual UUID override (otherwise auto-generated) |

---

## 🌐 Verifying Your Feed & API Status

1. **Live Feeder Status API:**  
   Call `https://api.airplanes.live/feed-status` from any device on the same public internet connection:
   ```json
   {
     "host": "YOUR_PUBLIC_IP",
     "beast_clients": [
       {
         "uuid": "your-station-uuid",
         "msgs_s": 98.4,
         "pos_s": 13.2,
         "pos": 520
       }
     ],
     "mlat_clients": [
       {
         "uuid": "your-station-uuid",
         "user": "My-Station-Name",
         "peer_count": 14,
         "message_rate": 86.2
       }
     ],
     "map_link": "https://globe.airplanes.live/?uuid=..."
   }
   ```
2. **Web Dashboard:**  
   Open [https://airplanes.live/myfeed/](https://airplanes.live/myfeed/) to view your feeder metrics and connection cards in your browser.
3. **Interactive Map:**  
   Open the `map_link` provided in `/feed-status` to view all aircraft currently tracked by your station on `globe.airplanes.live`.
4. **Local tar1090 Map:**  
   Open your local map (e.g. `http://<receiver-ip>:8080/`). Look at the flight table: aircraft located by Multilateration will show an `mlat` badge in the data source column.

---
---

<a name="-deutsch"></a>
# 🇩🇪 Deutsch

Extrem schlanker, hochperformanter Docker-Container zum Einspeisen von ADS-B- und MLAT-Daten (Multilateration) an [airplanes.live](https://airplanes.live/) – inklusive **lokalem MLAT-Rückkanal** in die eigene Empfänger-Webkarte (z. B. `tar1090` / `dump1090` / `readsb`).

---

## 🚀 Hauptmerkmale

* **Minimales Alpine-Linux-Image:** Multi-Stage Build mit nur ca. 25 MB Imagegröße und minimalem Ressourcenverbrauch auf dem Raspberry Pi.
* **Effizientes Beast-Streaming:** Nutzt `readsb` mit `beast_reduce_plus_out,uuid=...` für minimale Bandbreitennutzung bei maximaler Datenqualität.
* **Echte Multilateration (MLAT):** Integrierter `mlat-client` synchronisiert Mode-S Signale mit `feed.airplanes.live:31090`.
* **Lokaler MLAT-Rückkanal:** Berechnete Flugzeugpositionen werden direkt an den lokalen Empfänger (Port `30004`) zurückgemeldet und erscheinen mit `MLAT`-Tag auf deiner lokalen `tar1090`-Webkarte!
* **Persistente Station-UUID:** Generiert automatisch eine eindeutige Stations-UUID in `/var/lib/airplaneslive/uuid`, die über Docker-Volumes dauerhaft erhalten bleibt.

---

## 📦 Schnellstart mit Docker Compose

Füge den Dienst einfach zu deiner bestehenden `docker-compose.yml` hinzu:

```yaml
services:
  airplaneslive:
    build: https://github.com/MrCoopa/docker-airplaneslive-feeder.git#main
    container_name: airplaneslive-feeder
    restart: unless-stopped
    depends_on:
      - dump1090
    environment:
      # Verbindung zum lokalen ADS-B Decoder:
      - BEAST_HOST=dump1090
      - BEAST_PORT=30005

      # Antennen-Standort (Pflichtangabe für MLAT):
      - LAT=50.1234
      - LON=8.1234
      - ALT=150m

      # Name deiner Station auf airplanes.live:
      - USER=Meine-Station

      # MLAT & lokaler Rückkanal:
      - ENABLE_MLAT=true
      - MLAT_RESULTS_HOST=dump1090
      - MLAT_RESULTS_PORT=30004
    volumes:
      - airplaneslive-data:/var/lib/airplaneslive

volumes:
  airplaneslive-data:
```

### Starten & Protokolle ansehen

```bash
# Container starten / aktualisieren:
docker compose up -d --build airplaneslive

# Logs in Echtzeit prüfen:
docker compose logs -f airplaneslive
```

---

## 🌐 Verbindung prüfen (airplanes.live API)

1. **Feeder-Status API:**  
   Rufe im Browser oder Terminal [`https://api.airplanes.live/feed-status`](https://api.airplanes.live/feed-status) auf. Die API erkennt deine öffentliche IP automatisch und listet deine aktiven Verbindungen:
   * `beast_clients`: Zeigt Nachrichtenrate, Positionen und Bandbreite.
   * `mlat_clients`: Zeigt deinen Stationsnamen, Koordinaten und die Anzahl synchronisierter Nachbarstationen (`peer_count`).
2. **Status-Webseite:**  
   Unter [`https://airplanes.live/myfeed/`](https://airplanes.live/myfeed/) findest du das grafische Dashboard deiner Station.
3. **Eigene Flugzeuge auf der Weltkarte:**  
   Der in der API gelieferte `map_link` führt direkt auf die gefilterte Weltkarte deiner Station auf `globe.airplanes.live`.
4. **Lokale tar1090-Karte:**  
   Auf deiner lokalen Weboberfläche (`http://<raspi-ip>:8080/`) tauchen Flugzeuge ohne eigenes GPS nun mit dem Vermerk `mlat` auf.
