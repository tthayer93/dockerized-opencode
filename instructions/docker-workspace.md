# Docker & Host Workspace Rules

Your home directory `/workspace` in this container is a bind mount of the host directory `$HOST_WORKSPACE`. The Docker daemon is the **host's** daemon, so it only resolves **host paths** — it cannot see container-local paths.

Hard rules:

- ALL `docker` / `docker compose` invocations must mount volumes with host paths under `$HOST_WORKSPACE/<project>`. NEVER use container-local paths such as `/workspace/<project>` — the host cannot see them.
- Project compose files should interpolate the variable, e.g. `${HOST_WORKSPACE}/project-x:/app`.
- `$HOST_WORKSPACE` is exported in your environment and resolves automatically in shell commands and Docker Compose interpolation.
