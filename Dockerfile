FROM ghcr.io/anomalyco/opencode:latest

RUN apk add --no-cache \
  # Existing tools \
  ca-certificates bash git nodejs npm python3 py3-pip ripgrep jq wget openssh-client \
  # C/C++ toolchain \
  gcc g++ musl-dev clang cmake make gdb pkgconf \
  # Go \
  go \
  # Rust \
  rust cargo \
  # Python dev headers (for compiling Python C extensions) \
  python3-dev \
  # Ruby \
  ruby \
  # Networking \
  curl

COPY opencode.jsonc.default /opt/opencode/opencode.jsonc.default
COPY entrypoint.sh          /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspace
EXPOSE 4096

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
