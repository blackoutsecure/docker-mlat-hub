<p align="center">
  <img src="https://raw.githubusercontent.com/blackoutsecure/docker-mlat-hub/main/logo.png" alt="mlat-hub logo" width="200">
</p>

# blackoutsecure/mlat-hub

[![GitHub Stars](https://img.shields.io/github/stars/blackoutsecure/docker-mlat-hub?style=flat-square&color=E7931D&logo=github)](https://github.com/blackoutsecure/docker-mlat-hub/stargazers)
[![Docker Pulls](https://img.shields.io/docker/pulls/blackoutsecure/mlat-hub?style=flat-square&color=E7931D&logo=docker&logoColor=FFFFFF)](https://hub.docker.com/r/blackoutsecure/mlat-hub)
[![GitHub Release](https://img.shields.io/github/release/blackoutsecure/docker-mlat-hub.svg?style=flat-square&color=E7931D&logo=github&logoColor=FFFFFF)](https://github.com/blackoutsecure/docker-mlat-hub/releases)
[![Blackout Secure Launchpad](https://img.shields.io/github/actions/workflow/status/blackoutsecure/docker-mlat-hub/bos-launchpad-release.yml?style=flat-square&label=blackout%20secure%20launchpad&color=E7931D)](https://github.com/blackoutsecure/docker-mlat-hub/actions/workflows/bos-launchpad-release.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg?style=flat-square)](https://www.gnu.org/licenses/gpl-3.0)

Unofficial community image for [readsb](https://github.com/wiedehopf/readsb) configured as an MLAT hub, built with [LinuxServer.io](https://linuxserver.io/) style container patterns (s6, hardened defaults, practical runtime options). Aggregates multiple `mlat-client` Beast feeds into a single deduplicated Beast output for downstream tools (tar1090, dashboards, collectors). Sponsored and maintained by [Blackout Secure](https://blackoutsecure.app).

> [!IMPORTANT]
> This repository is not an official LinuxServer.io image release.
> Want to help make it an officially supported LinuxServer.io Community image?
> Add your support in [linuxserver/discussions/108](https://github.com/orgs/linuxserver/discussions/108).

> [!WARNING]
> MLAT results must **never** be forwarded back to feeders — doing so contaminates MLAT calculations and will get you banned from aggregation services. mlat-hub runs as a separate readsb instance specifically to prevent this cross-contamination.

Links: [Docker Hub](https://hub.docker.com/r/blackoutsecure/mlat-hub) · [Balena block](https://hub.balena.io/blocks/2354730/mlat-hub) · [GitHub](https://github.com/blackoutsecure/docker-mlat-hub) · [Upstream readsb](https://github.com/wiedehopf/readsb)

[![balena deploy button](https://www.balena.io/deploy.svg)](https://hub.balena.io/blocks/2354730/mlat-hub)

---

## Table of Contents

- [Quick Start](#quick-start)
- [Image Availability](#image-availability)
- [About The mlat-hub Application](#about-the-mlat-hub-application)
- [Supported Architectures](#supported-architectures)
- [Usage](#usage)
  - [Docker Compose](#docker-compose-recommended-click-here-for-more-info)
  - [Docker Compose (Full Stack)](#docker-compose-full-stack-readsb--mlat-clients--mlat-hub--tar1090)
  - [Docker CLI](#docker-cli-click-here-for-more-info)
  - [Balena Deployment](#balena-deployment)
- [Parameters](#parameters)
- [Volume Details](#volume-details)
- [Configuration](#configuration)
- [User / Group Identifiers](#user--group-identifiers)
- [Application Setup](#application-setup)
- [Connection Modes](#connection-modes)
- [Troubleshooting](#troubleshooting)
- [Health Monitoring](#health-monitoring)
- [Release & Versioning](#release--versioning)
- [Resources](#resources)
- [License](#license)

---

## Quick Start

**5-minute MLAT aggregator setup:**

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

For compose files, balena, full-stack examples, and connection modes, see [Usage](#usage) below.

---

## Image Availability

**Docker Hub (Recommended):**

- All images published to [Docker Hub](https://hub.docker.com/r/blackoutsecure/mlat-hub)
- Simple pull command: `docker pull blackoutsecure/mlat-hub:latest`
- Multi-arch support: amd64, arm64
- No registry prefix needed (defaults to Docker Hub)

```bash
# Pull latest
docker pull blackoutsecure/mlat-hub

# Pull specific version
docker pull blackoutsecure/mlat-hub:1.2.3

# Pull architecture-specific (rarely needed)
docker pull blackoutsecure/mlat-hub:latest@amd64
```

---

## About The mlat-hub Application

When you feed ADS-B data to multiple aggregation services (ADSBExchange, adsb.fi, airplanes.live, etc.), each service runs its own MLAT client that produces multilateration results on separate ports. **mlat-hub** combines all of these MLAT result feeds into a single, deduplicated Beast output for visualization tools like [tar1090](https://github.com/wiedehopf/tar1090) or data collectors.

Internally, mlat-hub runs upstream [readsb](https://github.com/wiedehopf/readsb) in network-only mode with `--forward-mlat` enabled — no SDR hardware required.

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

Author and maintenance credits (upstream):

- Primary upstream maintainer: [wiedehopf](https://github.com/wiedehopf) (Matthias Wirth)
- Upstream credits/history lineage: antirez (original dump1090), Malcom Robb, mutability (dump1090-mutability / dump1090-fa), Mictronics (readsb fork), and wiedehopf (current fork)
- Upstream repository and documentation: [wiedehopf/readsb](https://github.com/wiedehopf/readsb)

---

## Supported Architectures

This image is published as a multi-arch manifest. Pulling `blackoutsecure/mlat-hub:latest` retrieves the correct image for your host architecture.

The architectures supported by this image are:

| Architecture | Tag |
| :----: | --- |
| x86-64 | amd64-latest |
| arm64 | arm64v8-latest |

---

## Usage

### docker-compose (recommended, [click here for more info](https://docs.linuxserver.io/general/docker-compose))

```yaml
---
services:
  mlathub:
    image: blackoutsecure/mlat-hub:latest
    container_name: mlathub
    environment:
      - TZ=Etc/UTC
      - MLATHUB_INPUTS=mlat-adsbx,30105,beast_in;mlat-adsbfi,30105,beast_in
      - LOG_LEVEL=info                 # debug | info | warn | error | fatal
    ports:
      - 30104:30104  # Beast input (TCP) — push mode
      - 30105:30105  # Beast output (TCP) — combined MLAT results
    security_opt:
      - no-new-privileges:true
    tmpfs:
      - /tmp
      - /run:exec
    restart: unless-stopped
```

### docker-compose (full stack: readsb + mlat-clients + mlat-hub + tar1090)

A complete ADS-B receiver stack with readsb, multiple MLAT clients, mlat-hub, and tar1090:

```yaml
---
services:
  readsb:
    image: blackoutsecure/readsb:latest
    container_name: readsb
    environment:
      - TZ=Etc/UTC
      - READSB_DEVICE_TYPE=rtlsdr
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
    image: blackoutsecure/tar1090:latest
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

### docker-cli ([click here for more info](https://docs.docker.com/engine/reference/commandline/cli/))

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

This image can be deployed to Balena-powered IoT devices using the included `docker-compose.yml` file (which contains the required Balena labels):

- Balena block listing: [https://hub.balena.io/blocks/2354730/mlat-hub](https://hub.balena.io/blocks/2354730/mlat-hub)

```bash
balena push <your-app-slug>
```

For deployment via the web interface, use the deploy button in this repository. See [Balena documentation](https://docs.balena.io/) for details.

## Parameters

### Ports

| Parameter | Function |
| :----: | --- |
| `-p 30104:30104` | Beast protocol input (TCP) — feeder containers can push MLAT data here (push mode) |
| `-p 30105:30105` | Beast protocol output (TCP) — combined deduplicated MLAT results |

### Environment Variables

| Parameter | Function | Required |
| :----: | --- | :---: |
| `-e TZ=Etc/UTC` | Timezone ([TZ database](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List)) | Optional |
| `-e MLATHUB_INPUTS=` | Semicolon-separated `host,port,protocol` entries the hub will pull from. Example: `mlat-adsbx,30105,beast_in;mlat-adsbfi,30105,beast_in`. Required for pull mode; not required if you only use push mode. | Conditional |
| `-e MLATHUB_BEAST_OUTPUT_PORT=30105` | Beast protocol output port for combined MLAT results (default: `30105`) | Optional |
| `-e MLATHUB_BEAST_INPUT_PORT=30104` | Beast protocol input listen port for push mode (default: `30104`) | Optional |
| `-e MLATHUB_SBS_OUTPUT_PORT=` | Optional SBS/Basestation output port. Leave empty to disable. | Optional |
| `-e MLATHUB_EXTRA_ARGS=` | Additional readsb arguments appended after all env-var-driven options | Optional |
| `-e MLATHUB_USER=abc` | Runtime user (default: `abc`) | Optional |
| `-e PUID=1000` | User ID for file ownership (LinuxServer.io base image standard) | Optional |
| `-e PGID=1000` | Group ID for file ownership (LinuxServer.io base image standard) | Optional |
| `-e LOG_LEVEL=info` | Minimum log verbosity: `debug`, `info` (default), `warn`, `error`, `fatal` | Optional |

### Input Protocol Options

The `protocol` field in `MLATHUB_INPUTS` entries supports:

| Protocol | Description |
| :----: | --- |
| `beast_in` | Beast binary format (most common for MLAT results) |
| `raw_in` | Raw AVR format |
| `sbs_in` | SBS/Basestation format |

### Devices

This container does **not** require any USB or hardware devices — it runs in network-only mode and aggregates upstream Beast feeds.

---

## Volume Details

mlat-hub is **stateless** and does not require any persistent volumes. All MLAT input/output is over TCP, and the container holds only transient deduplication state in memory.

If you want a fully ephemeral/read-only filesystem, mount tmpfs for the standard scratch paths:

```yaml
tmpfs:
  - /tmp
  - /run:exec
```

This is already included in the recommended compose snippet above.

---

## Configuration

Environment variables are set using `-e` flags in `docker run` or the `environment:` section in docker-compose. See [Parameters](#parameters) for the full list.

---

## User / Group Identifiers

By default, this container runs as the LSIO `abc` user (non-root) for better security isolation. The `abc` user is created by the [LinuxServer.io base image](https://docs.linuxserver.io/general/understanding-puid-and-pgid/) with UID/GID 911 and remapped at container start via `PUID`/`PGID`.

**Non-root mode (default, recommended):**

- mlat-hub runs as the `abc` user by default
- No USB or device permissions are required
- Set `PUID` and `PGID` only if you need file ownership to match a specific host user

**Root mode (fallback):**

- Set `MLATHUB_USER=root` if needed for other reasons

---

## Application Setup

The container runs readsb in network-only mode with `--forward-mlat` enabled. It collects MLAT results from multiple feeder containers and outputs a single combined Beast feed.

### Key Features

- **Network-only readsb**: No SDR hardware, no RTL-SDR dependencies, no `/dev/bus/usb` mount required
- **Multi-source aggregation**: Pull MLAT Beast data from any number of `mlat-client` sidecars via `MLATHUB_INPUTS`
- **Push mode**: Accepts incoming Beast connections on `MLATHUB_BEAST_INPUT_PORT` (default `30104`)
- **Deduplication**: readsb merges overlapping MLAT positions from multiple sources into a single output stream
- **Combined Beast output**: Single port (`MLATHUB_BEAST_OUTPUT_PORT`, default `30105`) for downstream consumers
- **Optional SBS output**: Enable `MLATHUB_SBS_OUTPUT_PORT` for tools that consume SBS/Basestation format
- **Docker HEALTHCHECK**: Built-in health monitoring — marks container unhealthy if the Beast output port stops listening
- **Log Verbosity**: Set `LOG_LEVEL` to control log output: `debug`, `info` (default), `warn`, `error`, `fatal`

### Extra Arguments (MLATHUB_EXTRA_ARGS)

Most mlat-hub settings have dedicated `MLATHUB_*` env vars. Use `MLATHUB_EXTRA_ARGS` for anything not covered by a dedicated variable — these are appended to the end of the readsb command line after all env-var-driven options.

```bash
# Adjust beast reduce interval
-e MLATHUB_EXTRA_ARGS="--net-beast-reduce-interval 1.0"

# Tune TCP heartbeat
-e MLATHUB_EXTRA_ARGS="--net-heartbeat 30"
```

For all available readsb options, see the [readsb documentation](https://github.com/wiedehopf/readsb).

### Important Safety Notes

- **Never** forward mlat-hub's output back to your primary readsb feeder or to aggregation services. MLAT results are derived from aggregator timing — re-injecting them contaminates calculations and will get you banned. mlat-hub exists as a separate readsb instance specifically to prevent this.
- mlat-hub is intended for **local visualization and analytics only** (tar1090, dashboards, MQTT bridges, local databases).

### Supported Modes

- **Read-only filesystem**: Supported when `/tmp` and `/run` are mounted as tmpfs (see the recommended compose snippet)
- **Non-root user**: Supported by default — no device permissions are needed

---

## Connection Modes

There are two ways to get MLAT data into the hub. Both modes can be used simultaneously.

### Pull mode (recommended)

mlat-hub connects outbound to each mlat-client via `MLATHUB_INPUTS`:

```yaml
environment:
  - MLATHUB_INPUTS=mlat-adsbx,30105,beast_in;mlat-adsbfi,30105,beast_in
```

In this mode the `mlat-client` containers expose their MLAT result port (typically `beast,listen,30105`) and mlat-hub dials them.

### Push mode

mlat-client containers connect outbound to mlat-hub's Beast input port:

```bash
# mlat-client config
MLAT_CLIENT_RESULTS=beast,connect,mlathub:30104

# mlat-hub config (MLATHUB_INPUTS not required)
MLATHUB_BEAST_INPUT_PORT=30104
```

This is useful when mlat-client containers run on different hosts or in environments where the hub cannot reach them directly.

---

## Troubleshooting

### Container won't start or exits immediately

**Check logs:**

```bash
docker logs mlathub
docker logs mlathub --tail 50 -f  # Follow last 50 lines
```

**Common causes:**

- `MLATHUB_INPUTS` syntax error: must be semicolon-separated `host,port,protocol` triples
- Port conflict on the host: change the published port (e.g. `-p 31105:30105`)
- Configuration error: check `MLATHUB_EXTRA_ARGS` syntax against the [readsb documentation](https://github.com/wiedehopf/readsb)

### No MLAT data showing

1. Verify mlat-client containers are running and connected to their MLAT servers
2. Check mlat-hub logs: `docker logs mlathub`
3. Verify network connectivity between containers (must be on the same Docker network)
4. Ensure mlat-clients are outputting Beast data on the expected port
5. Confirm `MLATHUB_INPUTS` entries resolve — DNS names must match the mlat-client container names

### Check combined output

```bash
# Verify readsb process is running
docker exec mlathub ps aux | grep readsb

# Verify the s6 service is up
docker exec mlathub s6-svstat /run/service/svc-mlathub

# Verify the Beast output port is listening
docker exec mlathub ss -tln | grep 30105
```

### Common log messages

| Message | Meaning |
| --- | --- |
| `No MLAT inputs configured` | No outbound connections — use push mode or set `MLATHUB_INPUTS` |
| `N input(s), beast-out=30105` | Hub will connect to N mlat-client containers |

### Getting help

- Check [upstream readsb documentation](https://github.com/wiedehopf/readsb)
- Review container logs: `docker logs -f mlathub`
- Open an issue on [GitHub](https://github.com/blackoutsecure/docker-mlat-hub/issues)

---

## Health Monitoring

The container includes built-in health monitoring at multiple levels:

### Docker HEALTHCHECK

The image includes a `HEALTHCHECK` that verifies the Beast output port (`30105`) is in `LISTEN` state. Docker marks the container as `unhealthy` after 3 consecutive failures.

| Setting | Value |
| :----: | --- |
| Interval | 30s |
| Timeout | 5s |
| Start period | 60s |
| Retries | 3 |

```bash
# Check container health status
docker inspect --format='{{.State.Health.Status}}' mlathub

# View health check history
docker inspect --format='{{json .State.Health}}' mlathub | jq .
```

### s6 Service Supervision

All long-running services are supervised by s6-overlay and automatically restarted on crash:

```bash
# Check service status (equivalent of systemctl status)
docker exec mlathub s6-svstat /run/service/svc-mlathub
```

### Quick Status Commands

```bash
# Container health
docker inspect --format='{{.State.Health.Status}}' mlathub

# Beast output port listening
docker exec mlathub ss -tln | grep 30105

# Service uptime
docker exec mlathub s6-svstat /run/service/svc-mlathub

# Tail logs
docker logs -f mlathub
```

---

## Release & Versioning

This project uses [semantic versioning](https://semver.org/):

- Releases published on [GitHub Releases](https://github.com/blackoutsecure/docker-mlat-hub/releases)
- Multi-arch images (amd64, arm64v8) built automatically
- Docker Hub tags: version-specific, `latest`, and architecture-specific

**Update to latest:**

```bash
docker pull blackoutsecure/mlat-hub:latest
docker-compose up -d  # if using compose
```

**Check image version:**

```bash
docker inspect -f '{{ index .Config.Labels "org.opencontainers.image.version" }}' blackoutsecure/mlat-hub:latest
```

---

## Resources

- **Docker Hub:** [blackoutsecure/mlat-hub](https://hub.docker.com/r/blackoutsecure/mlat-hub)
- **Issues / bug reports:** [GitHub Issues](https://github.com/blackoutsecure/docker-mlat-hub/issues) — include Docker version, container logs, and reproduction steps.
- **Releases:** [GitHub Releases](https://github.com/blackoutsecure/docker-mlat-hub/releases)
- **Upstream:** [wiedehopf/readsb](https://github.com/wiedehopf/readsb)
- **Container base:** [LinuxServer.io](https://linuxserver.io/) · [Discord](https://linuxserver.io/discord)

---

## License

GPL-3.0-or-later — see [LICENSE](LICENSE). The upstream readsb project is also GPL-3.0-or-later.

Sponsored and maintained by [Blackout Secure](https://blackoutsecure.app).
