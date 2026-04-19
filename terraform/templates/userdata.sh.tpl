#!/bin/bash
set -euo pipefail

#
# Install Docker
#
dnf install -y docker git
systemctl enable --now docker

DOCKER_CONFIG=/usr/local/lib/docker
mkdir -p "$DOCKER_CONFIG/cli-plugins"
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
  -o "$DOCKER_CONFIG/cli-plugins/docker-compose"
chmod +x "$DOCKER_CONFIG/cli-plugins/docker-compose"

#
# Install certbot
#
dnf install -y certbot

#
# Clone and set up mirror
#
MIRROR_DIR=/opt/mirror
mkdir -p "$MIRROR_DIR"
cd "$MIRROR_DIR"

# Write authorized_keys for the tunnel user
cat > authorized_keys <<'AUTHEOF'
${mirror_authorized_key}
AUTHEOF

# Write .env
cat > .env <<'ENVEOF'
MIRROR_HOST=${domain}
MIRROR_PORT=${mirror_tunnel_port}
MIRROR_TLS=auto
MIRROR_HTTP_PORT=80
MIRROR_HTTPS_PORT=443
MIRROR_SSH_PORT=${mirror_ssh_port}
ENVEOF

# Write docker-compose.yml
cat > docker-compose.yml <<'COMPEOF'
services:
  mirror:
    build: /opt/mirror/repo/server
    container_name: mirror
    restart: unless-stopped
    ports:
      - "${mirror_ssh_port}:2222"
    network_mode: host
    environment:
      MIRROR_HOST: ${domain}
      MIRROR_PORT: ${mirror_tunnel_port}
      MIRROR_TLS: auto
    volumes:
      - /etc/letsencrypt:/etc/letsencrypt:ro
      - /var/www/letsencrypt:/var/www/letsencrypt:ro
      - mirror-sshkeys:/etc/ssh/keys
    secrets:
      - mirror_authorized_keys

secrets:
  mirror_authorized_keys:
    file: /opt/mirror/authorized_keys

volumes:
  mirror-sshkeys:
COMPEOF

#
# Clone the repo to get the Dockerfile and rootfs
#
git clone https://github.com/stikki/mirror.git /opt/mirror/repo || true

#
# Obtain TLS certificate (standalone — nothing on port 80 yet)
#
mkdir -p /var/www/letsencrypt
certbot certonly --standalone --non-interactive --agree-tos \
  --register-unsafely-without-email \
  -d "${domain}" \
  --deploy-hook "docker exec mirror angie -s reload 2>/dev/null || true"

#
# Build and start
#
cd "$MIRROR_DIR"
docker compose up -d --build

#
# Certbot auto-renewal cron
#
echo "0 3 * * * root certbot renew --quiet --deploy-hook 'docker exec mirror angie -s reload'" \
  > /etc/cron.d/certbot-mirror
