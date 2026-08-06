# Render free web service: SOCKS5 egress peer for opencode-zen IP rotation.
#
# Architecture: Render free instances are outbound-only (no inbound arbitrary
# TCP, no shell, ephemeral disk) and spin down after 15 min without inbound
# HTTP/WS traffic. So this container:
#   1. runs microsocks on 127.0.0.1:1080 (anonymous SOCKS5, container-local),
#   2. opens an OUTBOUND reverse SSH tunnel to the homelab CI sshd
#      (nadruvos.jautis.lt:6022, same public path GitHub Actions uses),
#      forwarding -R 127.0.0.1:1094:127.0.0.1:1080. The homelab zen-proxy
#      treats socks5://127.0.0.1:1094 as a normal peer and egresses through
#      THIS container's public IP.
#   3. serves a tiny HTTP health page on $PORT so the homelab keep-alive timer
#      (curl every ~5 min) prevents Render's 15-min idle spin-down.
#
# The private SSH key is injected at runtime via the RENDER_SSH_KEY env secret.
FROM alpine:3.20

RUN apk add --no-cache \
      autossh \
      microsocks \
      openssh-client \
      busybox

COPY entrypoint.sh /entrypoint.sh
RUN chmod 0755 /entrypoint.sh

EXPOSE 10000

ENTRYPOINT ["/entrypoint.sh"]
