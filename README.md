# dockerized-opencode

Docker Compose setup for running [Opencode](https://opencode.ai) with persistent sessions, web UI access, and direct access to the host's Docker daemon.

## Features

- **Persistent Data**: Sessions, auth tokens, and logs survive container restarts via bind mounts.
- **Non-root User**: Runs as a dedicated non-root user (`appuser`) with `no-new-privileges` security hardening. Note this does **not** isolate you from the host: the mounted Docker socket grants host root (see [Docker Socket Integration](#docker-socket-integration)).
- **Zero Config Start**: Seeds a default `opencode.jsonc` on first run if none exists.

## Included Dev Tools

The container ships with a set of compilers, runtimes, and utilities so opencode can build and test code out of the box:

| Category | Tools |
|---|---|
| **C/C++** | `gcc`, `g++`, `clang`, `musl-dev`, `cmake`, `make`, `gdb`, `pkgconf` |
| **Go** | `go` |
| **Rust** | `rust`, `cargo` |
| **Python** | `python3`, `pip`, `python3-dev` (headers for C extensions) |
| **Ruby** | `ruby` |
| **Node.js** | `nodejs`, `npm` |
| **Networking** | `curl`, `wget`, `openssh-client` |
| **GitHub CLI** | `gh` |
| **Docker** | `docker` (CLI) |
| **CLI Utilities** | `bash`, `git`, `jq`, `ripgrep`, `less`, `sed`, `awk` |

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose V2](https://docs.docker.com/compose/install/)

## Quick Start

```bash
# 1. Copy the env template and adjust PUID/PGID and HOST_WORKSPACE to match your host
cp .env.example .env

# 2. Set correct ownership on bind-mount directories before first run
sudo chown -R $(id -u):$(id -g) /mnt/workspace config data

# 3. Pull the pre-built image and start
docker compose up -d
```

The project source code is read from the host directory set by `HOST_WORKSPACE` (default `/mnt/workspace`) and mounted at `/workspace` inside the container. Note that `HOST_WORKSPACE` must point to an existing directory — Docker will not create it for you.

The web UI is available at `http://localhost:4096`.

## Build Locally

If you prefer to build the image yourself instead of pulling the pre-built one, swap the `image:` directive for `build:` in `docker-compose.yml`:

```yaml
services:
  opencode:
    # image: ghcr.io/tthayer93/dockerized-opencode:latest
    build: .
```

Then start with:

```bash
docker compose up -d --build
```

## Directory Structure

| Host Path | Container Path | Purpose |
|---|---|---|
| `${HOST_WORKSPACE}` (default `/mnt/workspace/`) | `/workspace` | Your project source code (bind mounted) |
| `./config/` | `/home/appuser/.config/opencode` | Server settings (`opencode.jsonc`) — created on first run if missing |
| `./data/` | `/home/appuser/.local/share/opencode` | Sessions, auth tokens, logs (persistent across restarts) |

## Configuration

Copy `.env.example` to `.env` and set the required values:

- **PUID / PGID** — match your host user so bind mounts have correct ownership.
- **OPENCODE_PASSWORD** — basic auth password for remote access (recommended). In V2 the username is fixed to `opencode`; only the password is configurable.

LLM provider API keys and other settings are configured directly inside `./config/opencode.jsonc`. The entrypoint seeds a minimal default config on first run if the file does not exist yet. You can edit it later to add providers, models, CORS, LSP servers, or any other advanced settings documented in the [Opencode configuration guide](https://opencode.ai/docs/config/).

### Port & Network Settings

The web UI port and network binding are controlled by the `opencode serve --hostname/--port` flags in `entrypoint.sh` (defaults: `0.0.0.0:4096`, overridable via `OPENCODE_SERVE_HOSTNAME`/`OPENCODE_SERVE_PORT` env vars), and stay in sync with the container's `ports` mapping and health check. In V2, `server.port`/`server.hostname` in `opencode.jsonc` are **accepted but ignored** — do not rely on them; they will not change what the container listens on.

## Command-Line Interface (TUI)

You can interact with opencode directly in your terminal while the container is running. Because sessions are stored in the persistent `./data/` volume, any work you do in the TUI will be saved and visible in the web interface.

### Attaching to the Web Server
To share live state with an already-running web server (recommended), `cd` into your project directory and pass the server URL via `--server`:

```bash
docker exec -it opencode su -s /bin/sh appuser -c "cd /workspace/your-project && exec opencode --server http://localhost:4096"
```

> **Note:** `cd` into the specific project directory before running `opencode`. V2 organizes sessions by the current working directory (project slug), so running from `/workspace` instead of a sub-project will show sessions in a generic context in the web UI.

*(The container already exports `OPENCODE_PASSWORD` in its environment, so no additional auth flag is needed for the client — the CLI reads `OPENCODE_PASSWORD` automatically.)*

## Private Repositories

To allow opencode to clone and push to private repositories, place your `.gitconfig` and `.ssh/` directory in your `HOST_WORKSPACE` directory (mounted at `/workspace`). The entrypoint symlinks these into the container user's home directory on first run. Empty placeholders are created automatically if missing, allowing you to copy your actual SSH keys and git config into that directory at any time without restarting the container.

## Docker Socket Integration

The `docker` CLI is included and the host's Docker socket is mounted at `/var/run/docker.sock`, so opencode can build images and manage containers on the host directly. The entrypoint grants the container user access to the socket on each start.

### Why `$HOST_WORKSPACE` exists

The host's Docker daemon resolves volume mounts against **host paths**, which it cannot see from inside this container. `HOST_WORKSPACE` tells opencode (and its agents) where the workspace lives on the host, so they can spawn containers that actually use the workspace.

Agents run under a hard prompt rule (shipped in `instructions/docker-workspace.md` and injected via the default `opencode.jsonc`'s `instructions` field):

- **All `docker` invocations must mount volumes with host paths under `$HOST_WORKSPACE/<project>`** — never container-local paths like `/workspace/<project>`, which the host cannot see.
- Project compose files can interpolate the variable directly: `${HOST_WORKSPACE}/project-x:/app`.

`HOST_WORKSPACE` is exported into the container environment, so it resolves automatically in shell commands and Docker Compose interpolation.

> **Security note:** Control of the Docker socket is equivalent to **root access on the host**. Anyone with access to this container can escape to the host (e.g. by `docker run -v /:/host` mounting the host filesystem). If you don't need this, remove the socket volume from `docker-compose.yml`.

## Troubleshooting

### Permission Denied Errors
If opencode fails with `EACCES: permission denied`, the bind-mount directories are owned by root instead of your user. Fix them before starting:
```bash
sudo chown -R $(id -u):$(id -g) config data workspace
docker compose restart
```

### Health Check Failing Immediately
Ensure you have set a `start_period` in compose (default is 20s). Opencode may take several seconds to initialize LSP servers and load provider packages on cold start.
