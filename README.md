# dockerized-opencode

Docker Compose setup for running [Opencode](https://opencode.ai) with persistent sessions, web UI access, and non-root user isolation.

## Features

- **Persistent Data**: Sessions, auth tokens, and logs survive container restarts via bind mounts.
- **Secure by Default**: Runs as a dedicated non-root user (`appuser`) with `no-new-privileges` security hardening.
- **Zero Config Start**: Seeds a default `opencode.jsonc` on first run if none exists.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose V2](https://docs.docker.com/compose/install/)

## Quick Start

```bash
# 1. Copy the env template and adjust PUID/PGID to match your host user
cp .env.example .env

# 2. Set correct ownership on bind-mount directories before first run
sudo chown -R $(id -u):$(id -g) config data workspace

# 3. Build and start
docker compose up -d --build
```

The web UI is available at `http://localhost:4096`.

## Directory Structure

| Host Path | Container Path | Purpose |
|---|---|---|
| `./workspace/` | `/workspace` | Your project source code (bind mounted) |
| `./config/` | `/home/appuser/.config/opencode` | Server settings (`opencode.jsonc`) — created on first run if missing |
| `./data/` | `/home/appuser/.local/share/opencode` | Sessions, auth tokens, logs (persistent across restarts) |

## Configuration

Copy `.env.example` to `.env` and set the required values:

- **PUID / PGID** — match your host user so bind mounts have correct ownership.
- **OPENCODE_SERVER_PASSWORD** — basic auth password for remote access (recommended).

LLM provider API keys and other settings are configured directly inside `./config/opencode.jsonc`. The entrypoint seeds a minimal default config on first run if the file does not exist yet. You can edit it later to add providers, models, CORS, LSP servers, or any other advanced settings documented in the [Opencode configuration guide](https://opencode.ai/docs/config/).

### Port & Network Settings

The web UI port and network binding are managed through `docker-compose.yml` to ensure they stay in sync with container networking and health checks. To change the exposed host port, modify the `ports` mapping in compose. Do not change `server.port` inside `./config/opencode.jsonc`, as this will cause the Docker health check to fail.

## Command-Line Interface (TUI)

You can interact with opencode directly in your terminal while the container is running. Because sessions are stored in the persistent `./data/` volume, any work you do in the TUI will be saved and visible in the web interface.

### Attaching to the Web Server
To share live state with an already-running web server (recommended):
```bash
docker exec -it opencode su -s /bin/sh appuser -c "opencode attach http://localhost:4096 --dir /workspace/your-project"
```
> **Note:** Use the `--dir` flag to specify your project folder. Opencode organizes sessions by project slug, and omitting this flag defaults to `/workspace`, which may cause sessions to appear in a generic context instead of your specific sub-project in the web UI.

*(If you have `OPENCODE_SERVER_PASSWORD` set, append `--password your-password` to the command.)*

## Private Repositories

To allow opencode to clone and push to private repositories, place your `.gitconfig` and `.ssh/` directory in `./workspace/`. The entrypoint symlinks these into the container user's home directory on first run. Empty placeholders are created automatically if missing, allowing you to copy your actual SSH keys and git config into `./workspace/` at any time without restarting the container.

## Troubleshooting

### Permission Denied Errors
If opencode fails with `EACCES: permission denied`, the bind-mount directories are owned by root instead of your user. Fix them before starting:
```bash
sudo chown -R $(id -u):$(id -g) config data workspace
docker compose restart
```

### Health Check Failing Immediately
Ensure you have set a `start_period` in compose (default is 20s). Opencode may take several seconds to initialize LSP servers and load provider packages on cold start.
