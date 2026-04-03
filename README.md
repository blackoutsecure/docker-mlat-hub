<p align="center">
  <img src="https://raw.githubusercontent.com/blackoutsecure/docker-mlat-hub/main/logo.png" alt="mlat-hub logo" width="200">
</p>

# blackoutsecure/mlat-hub

[![GitHub Stars](https://img.shields.io/github/stars/blackoutsecure/docker-mlat-hub?style=flat-square&color=E7931D&logo=github)](https://github.com/blackoutsecure/docker-mlat-hub/stargazers)
[![Docker Pulls](https://img.shields.io/docker/pulls/blackoutsecure/mlat-hub?style=flat-square&color=E7931D&logo=docker&logoColor=FFFFFF)](https://hub.docker.com/r/blackoutsecure/mlat-hub)
[![GitHub Release](https://img.shields.io/github/release/blackoutsecure/docker-mlat-hub.svg?style=flat-square&color=E7931D&logo=github&logoColor=FFFFFF)](https://github.com/blackoutsecure/docker-mlat-hub/releases)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg?style=flat-square)](https://www.gnu.org/licenses/gpl-3.0)

LinuxServer.io containerized MLAT hub aggregating [readsb](https://github.com/wiedehopf/readsb) network-only feeds into one combined Beast output.

Sponsored and maintained by [Blackout Secure](https://blackoutsecure.app).

> [!IMPORTANT]
> This is not an official LinuxServer.io image release.

## Overview

When you feed ADS-B data to multiple aggregation services (ADSBExchange, adsb.fi, airplanes.live, etc.), each service runs its own MLAT client that produces multilateration results on separate ports. **mlat-hub** combines all of these MLAT result feeds into a single, deduplicated Beast output for visualization tools like [tar1090](https://github.com/wiedehopf/tar1090) or data collectors.

> [!WARNING]
> MLAT results must **never** be forwarded back to feeders — doing so contaminates MLAT calculations and will get you banned from aggregation services. mlat-hub runs as a separate readsb instance specifically to prevent this cross-contamination.

| | |
| --- | --- |
| Docker Hub | [blackoutsecure/mlat-hub](https://hub.docker.com/r/blackoutsecure/mlat-hub) |
| GitHub | [blackoutsecure/docker-mlat-hub](https://github.com/blackoutsecure/docker-mlat-hub) |
| Balena Hub | [mlat-hub block](https://hub.balena.io/blocks/2354730/mlat-hub) |
| Upstream | [wiedehopf/readsb](https://github.com/wiedehopf/readsb) |

---

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [How It Works](#how-it-works)
- [Supported Architectures](#supported-architectures)
- [Usage](#usage)
- [Parameters](#parameters)
- [Connection Modes](#connection-modes)
- [Troubleshooting](#troubleshooting)
- [User / Group Identifiers](#user--group-identifiers)
- [References](#references)

---

## Quick Start

```bash
docker run -d \
  --name=mlathub \
  --restart unless-stopped \
  -e TZ=Etc/UTC \
  -e MLATHUB_INPUTS="mlat-adsbx,30105,beast_in;mlat-adsbfi,30105,beast_in" \
  -p 30104:30104 \
  -p 30105:30105 \
  --security-opt no-new-privileges:true \
  blackoutsecure/mlat-hub:latest
```

Combined MLAT results are available on port **30105** (Beast protocol).

---

## How It Works

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  mlat-client │    │  mlat-client │    │  mlat-client │
│  (ADSBx)     │    │  (adsb.fi)   │    │  (airplanes  │
│  :30105      │    │  :30105      │    │   .live)     │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                   │                   │
       │     beast_in      │     beast_in      │     beast_in
       └───────────────────┼───────────────────┘
                           │
                    ┌──────▼───────┐
                    │   mlat-hub   │
                    │  (readsb     │
                    │   --net-only │
                    │   --forward  │
                    │    -mlat)    │
                    └──────┬───────┘
                           │
                   Beast output :30105
                           │
              ┌────────────┼────────────┐
              │            │            │
       ┌──────▼──────┐ ┌──▼───┐ ┌──────▼──────┐
       │   tar1090   │ │ adsb │ │  influxdb/  │
       │   (map UI)  │ │ -to- │ │  grafana    │
       └─────────────┘ │ mqtt │ └─────────────┘
                       └──────┘
```

1. Each **mlat-client** container connects to an aggregation service and produces MLAT results on port 30105
2. **mlat-hub** connects to each mlat-client (via `--net-connector`) and ingests the Beast data
3. readsb deduplicates overlapping positions from multiple sources
4. The combined feed is output on Beast port 30105
5. Visualization tools (tar1090, etc.) connect to mlat-hub for MLAT data

---

## Supported Architectures

Multi-arch manifest — pulling `blackoutsecure/mlat-hub:latest` retrieves the correct image for your host.

| Architecture | Tag |
| :----: | --- |
| x86-64 | amd64-latest |
| arm64 | arm64v8-latest |

---

## Usage

### Docker Compose (recommended)

```yaml
---
services:
  mlathub:
    image: blackoutsecure/mlat-hub:latest
    container_name: mlathub
    environment:
      - TZ=Etc/UTC
      - MLATHUB_INPUTS=mlat-adsbx,30105,beast_in;mlat-adsbfi,30105,beast_in
    ports:
      - 30104:30104
      - 30105:30105
    security_opt:
      - no-new-privileges:true
    tmpfs:
      - /tmp
      - /run:exec
    restart: unless-stopped
```

### Full Stack Example

A complete ADS-B receiver stack with readsb, multiple MLAT clients, mlat-hub, and tar1090:

```yaml
---
services:
  readsb:
    image: blackoutsecure/readsb:latest
    container_name: readsb
    environment:
      - TZ=Etc/UTC
      - READSB_ARGS=--net --device-type rtlsdr
      - READSB_AUTOGAIN=true
      - FEED_PROFILES=adsbexchange,adsb-fi
      - FEED_LAT=51.5074
      - FEED_LON=-0.1278
    volumes:
      - readsb-config:/config
      - readsb-run:/run/readsb
    devices:
      - /dev/bus/usb:/dev/bus/usb
    ports:
      - 30003:30003
      - 30005:30005
    restart: unless-stopped

  mlat-adsbx:
    image: blackoutsecure/mlat-client:latest
    container_name: mlat-adsbx
    environment:
      - MLAT_CLIENT_INPUT_CONNECT=readsb:30005
      - MLAT_CLIENT_SERVER=feed.adsbexchange.com:31090
      - MLAT_CLIENT_LAT=51.5074
      - MLAT_CLIENT_LON=-0.1278
      - MLAT_CLIENT_ALT=50m
      - MLAT_CLIENT_RESULTS=beast,listen,30105
    depends_on: [readsb]
    restart: unless-stopped

  mlat-adsbfi:
    image: blackoutsecure/mlat-client:latest
    container_name: mlat-adsbfi
    environment:
      - MLAT_CLIENT_INPUT_CONNECT=readsb:30005
      - MLAT_CLIENT_SERVER=feed.adsb.fi:31090
      - MLAT_CLIENT_LAT=51.5074
      - MLAT_CLIENT_LON=-0.1278
      - MLAT_CLIENT_ALT=50m
      - MLAT_CLIENT_RESULTS=beast,listen,30105
    depends_on: [readsb]
    restart: unless-stopped

  mlathub:
    image: blackoutsecure/mlat-hub:latest
    container_name: mlathub
    environment:
      - TZ=Etc/UTC
      - MLATHUB_INPUTS=mlat-adsbx,30105,beast_in;mlat-adsbfi,30105,beast_in
    ports:
      - 30105:30105
    security_opt:
      - no-new-privileges:true
    tmpfs:
      - /tmp
      - /run:exec
    depends_on:
      - mlat-adsbx
      - mlat-adsbfi
    restart: unless-stopped

  tar1090:
    image: mikenye/tar1090:latest
    container_name: tar1090
    environment:
      - TZ=Etc/UTC
      - BEASTHOST=readsb
      - MLATHOST=mlathub
      - LAT=51.5074
      - LONG=-0.1278
    ports:
      - 8078:80
    depends_on:
      - readsb
      - mlathub
    restart: unless-stopped

volumes:
  readsb-config:
  readsb-run:
```

### Docker CLI

```bash
docker run -d \
  --name=mlathub \
  -e TZ=Etc/UTC \
  -e MLATHUB_INPUTS="mlat-adsbx,30105,beast_in;mlat-adsbfi,30105,beast_in" \
  -p 30104:30104 \
  -p 30105:30105 \
  --security-opt no-new-privileges:true \
  --restart unless-stopped \
  blackoutsecure/mlat-hub:latest
```

### Balena Deployment

Deploy to Balena-powered IoT devices using the included `docker-compose.yml`:

```bash
balena push <your-app-slug>
```

See the [Balena Hub listing](https://hub.balena.io/blocks/2354730/mlat-hub) for details.

---

## Parameters

### Ports

| Port | Function |
| :----: | --- |
| `30104` | Beast input — feeder containers can push MLAT data here |
| `30105` | Beast output — combined MLAT results |

### Environment Variables

| Variable | Default | Description |
| :--- | :----: | --- |
| `TZ` | `Etc/UTC` | Timezone ([TZ database](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List)) |
| `MLATHUB_INPUTS` | *(empty)* | **Required.** Semicolon-separated `host,port,protocol` entries. Example: `mlat-adsbx,30105,beast_in;mlat-adsbfi,30105,beast_in` |
| `MLATHUB_BEAST_OUTPUT_PORT` | `30105` | Beast output port for combined MLAT results |
| `MLATHUB_BEAST_INPUT_PORT` | `30104` | Beast input listen port (push mode) |
| `MLATHUB_SBS_OUTPUT_PORT` | *(disabled)* | Optional SBS/Basestation output port |
| `MLATHUB_EXTRA_ARGS` | *(empty)* | Additional readsb arguments |
| `MLATHUB_USER` | `abc` | Runtime user |
| `PUID` | `911` | User ID for file ownership |
| `PGID` | `911` | Group ID for file ownership |

### Input Protocol Options

The `protocol` field in `MLATHUB_INPUTS` entries supports:

| Protocol | Description |
| :----: | --- |
| `beast_in` | Beast binary format (most common for MLAT results) |
| `raw_in` | Raw AVR format |
| `sbs_in` | SBS/Basestation format |

---

## Connection Modes

There are two ways to get MLAT data into the hub:

**Pull mode (recommended):** mlat-hub connects to each mlat-client via `MLATHUB_INPUTS`:

```
MLATHUB_INPUTS=mlat-adsbx,30105,beast_in;mlat-adsbfi,30105,beast_in
```

**Push mode:** MLAT clients connect to the hub's Beast input port:

```bash
# mlat-client config
MLAT_CLIENT_RESULTS=beast,connect,mlathub:30104

# mlat-hub config (MLATHUB_INPUTS not required)
MLATHUB_BEAST_INPUT_PORT=30104
```

Both modes can be used simultaneously.

---

## Troubleshooting

### No MLAT Data Showing

1. Verify mlat-client containers are running and connected to their MLAT servers
2. Check mlat-hub logs: `docker logs mlathub`
3. Verify network connectivity between containers (must be on the same Docker network)
4. Ensure mlat-clients are outputting Beast data on the expected port

### Check Combined Output

```bash
docker exec mlathub ps aux | grep readsb
docker exec mlathub s6-svstat /run/service/svc-mlathub
```

### Common Log Messages

| Message | Meaning |
| --- | --- |
| `No MLAT inputs configured` | No outbound connections — use push mode or set `MLATHUB_INPUTS` |
| `N input(s), beast-out=30105` | Hub will connect to N mlat-client containers |

---

## User / Group Identifiers

Runs as the LinuxServer.io `abc` user (non-root) by default. Set `PUID` and `PGID` to match a specific host user for file ownership.

---

## Support & Getting Help

- [Open an issue](https://github.com/blackoutsecure/docker-mlat-hub/issues) on GitHub
- [Blackout Secure](https://blackoutsecure.app) — maintainer

---

## References

- [wiedehopf/readsb](https://github.com/wiedehopf/readsb) — upstream decoder used by mlat-hub
- [LinuxServer.io base images](https://docs.linuxserver.io/) — container infrastructure
