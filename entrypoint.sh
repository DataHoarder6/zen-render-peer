#!/bin/sh
# zen-render-peer entrypoint.
#
# Env expected:
#   RENDER_SSH_KEY  - private ed25519 key whose pubkey is in the homelab CI
#                     sshd's AuthorizedKeysFile (declared in ci-sshd.nix).
#   PORT            - Render-injected web service port (default 10000).
set -e

PORT="${PORT:-10000}"

# 1) Tiny HTTP health server so Render + the homelab keep-alive curl see an
#    up service. busybox httpd is built into alpine's busybox.
mkdir -p /var/www
printf 'ok\n' > /var/www/health
busybox httpd -f -h /var/www -p "${PORT}" &
HTTPD_PID=$!

# 2) SOCKS5 listener, container-local only. Homelab reaches it through the
#    reverse SSH forward.
microsocks -i 127.0.0.1 -p 1080 &
SOCKS_PID=$!

# 3) Materialize the SSH key from the Render secret env.
mkdir -p /root/.ssh
chmod 700 /root/.ssh
if [ -z "${RENDER_SSH_KEY}" ]; then
  echo "FATAL: RENDER_SSH_KEY env secret is not set" >&2
  exit 1
fi
printf '%s\n' "${RENDER_SSH_KEY}" > /root/.ssh/render_key
chmod 600 /root/.ssh/render_key

# 4) Keep the reverse tunnel alive. ExitOnForwardFailure makes autossh bail and
#    reconnect when the remote forward is not established; ServerAlive keeps the
#    connection from being reaped as idle. autossh monitors the ssh process and
#    reconnects on drop.
exec autossh -M 0 -N \
  -R 127.0.0.1:1094:127.0.0.1:1080 \
  -i /root/.ssh/render_key \
  -o StrictHostKeyChecking=accept-new \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -o ExitOnForwardFailure=yes \
  -p 6022 \
  root@nadruvos.jautis.lt
