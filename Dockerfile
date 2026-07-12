FROM ghcr.io/anomalyco/opencode:latest

RUN apk add --no-cache ca-certificates bash git nodejs npm python3 py3-pip ripgrep jq wget openssh-client

COPY opencode.jsonc.default /opt/opencode/opencode.jsonc.default
COPY entrypoint.sh          /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspace
EXPOSE 4096

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
