#!/usr/bin/env bash
set -euo pipefail

: "${MIRROR_HOST:?MIRROR_HOST required}"
: "${MIRROR_PORT:=7000}"
: "${MIRROR_TLS:=auto}"

#
# Render Angie config from template
#
if [[ "$MIRROR_TLS" == "off" ]]; then
  TEMPLATE=/etc/angie/templates/mirror.http.conf.template
else
  TEMPLATE=/etc/angie/templates/mirror.conf.template
fi

sed "s/__MIRROR_HOST__/$MIRROR_HOST/g; s/__MIRROR_PORT__/$MIRROR_PORT/g" \
  "$TEMPLATE" > /etc/angie/http.d/mirror.conf

# Remove Alpine's default config so it doesn't conflict
rm -f /etc/angie/http.d/default.conf

#
# Generate sshd host keys on first run (persisted via volume at /etc/ssh/keys)
#
if [[ ! -f /etc/ssh/keys/ssh_host_ed25519_key ]]; then
  ssh-keygen -t ed25519 -N '' -f /etc/ssh/keys/ssh_host_ed25519_key
  ssh-keygen -t rsa -b 4096 -N '' -f /etc/ssh/keys/ssh_host_rsa_key
fi

#
# Install authorized_keys from mounted secret
#
if [[ -f /run/secrets/mirror_authorized_keys ]]; then
  install -m 600 -o mirror -g mirror \
    /run/secrets/mirror_authorized_keys /home/mirror/.ssh/authorized_keys
fi

if [[ ! -s /home/mirror/.ssh/authorized_keys ]]; then
  printf 'WARNING: /home/mirror/.ssh/authorized_keys is empty. No client can connect.\n' >&2
fi

#
# Validate Angie config before launching
#
angie -t

#
# Start daemons. tini reaps zombies; if either dies, kill the other so the container exits.
#
/usr/sbin/sshd -D -e &
SSHD_PID=$!

angie -g 'daemon off;' &
ANGIE_PID=$!

trap 'kill -TERM "$SSHD_PID" "$ANGIE_PID" 2>/dev/null || true' TERM INT

wait -n "$SSHD_PID" "$ANGIE_PID"
kill -TERM "$SSHD_PID" "$ANGIE_PID" 2>/dev/null || true
wait
