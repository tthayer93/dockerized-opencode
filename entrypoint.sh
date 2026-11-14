#!/bin/sh
set -e

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"
CONFIG="/home/appuser/.config/opencode/opencode.jsonc"
SERVE_HOSTNAME="${OPENCODE_SERVE_HOSTNAME:-0.0.0.0}"
SERVE_PORT="${OPENCODE_SERVE_PORT:-4096}"

addgroup -g "$PGID" appuser >/dev/null 2>&1 || true
adduser -u "$PUID" -G appuser -h /home/appuser -s /bin/sh -D appuser >/dev/null 2>&1 || true

# Symlink Git credentials from workspace into the user's home directory.
# If they don't exist yet, create empty placeholders so Docker doesn't break them on restart.
if [ ! -f "/workspace/.gitconfig" ]; then
  touch "/workspace/.gitconfig"
fi
[ ! -e "/home/appuser/.gitconfig" ] && ln -s /workspace/.gitconfig /home/appuser/.gitconfig

if [ ! -d "/workspace/.ssh" ]; then
  mkdir -p "/workspace/.ssh"
fi
chmod 700 "/workspace/.ssh"
chmod 600 "/workspace/.ssh/id_*" 2>/dev/null || true
[ ! -e "/home/appuser/.ssh" ] && ln -s /workspace/.ssh /home/appuser/.ssh

# Create and chown directories needed by opencode.
mkdir -p \
    "/home/appuser/.config/opencode" \
    "/home/appuser/.local/share" \
    "/home/appuser/.local/state"
chown "${PUID}:${PGID}" /home/appuser \
    "/home/appuser/.config" \
    "/home/appuser/.local" \
    "/home/appuser/.local/share" \
    "/home/appuser/.local/state"

# If the host Docker socket is mounted, grant the container user access to it.
if [ -S /var/run/docker.sock ]; then
  sockGid="$(stat -c %g /var/run/docker.sock)"
  groupadd -g "$sockGid" docker 2>/dev/null || true
  usermod -aG docker appuser 2>/dev/null || true
  chmod 666 /var/run/docker.sock 2>/dev/null || true
fi

[ ! -f "$CONFIG" ] && cp /opt/opencode/opencode.jsonc.default "$CONFIG"

cd /workspace || exit 1
exec su -s /bin/sh appuser -c "cd /workspace && exec opencode serve --hostname ${SERVE_HOSTNAME} --port ${SERVE_PORT}"
