#!/bin/bash
set -euo pipefail

#
# Install Docker
#
dnf install -y docker git bind-utils
systemctl enable --now docker

DOCKER_CONFIG=/usr/local/lib/docker
mkdir -p "$DOCKER_CONFIG/cli-plugins"
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
  -o "$DOCKER_CONFIG/cli-plugins/docker-compose"
chmod +x "$DOCKER_CONFIG/cli-plugins/docker-compose"

#
# Clone the repo
#
git clone https://github.com/Stikki/mirror.git /opt/mirror
cd /opt/mirror/deploy

#
# Write instance-specific files
#
cat > .env <<ENVEOF
MIRROR_HOST=${domain}
MIRROR_PORT=${mirror_tunnel_port}
MIRROR_TLS=auto
ENVEOF

cat > authorized_keys <<'AUTHEOF'
${mirror_authorized_key}
AUTHEOF

#
# Wait for DNS to propagate before requesting TLS cert
#
mkdir -p /var/www/letsencrypt
for i in $(seq 1 30); do
  if dig +short "${domain}" 2>/dev/null | grep -q .; then
    break
  fi
  sleep 10
done

dnf install -y certbot
certbot certonly --standalone --non-interactive --agree-tos \
  --register-unsafely-without-email \
  -d "${domain}" \
  --deploy-hook "docker exec mirror angie -s reload 2>/dev/null || true"

#
# Pull and start
#
docker compose up -d

#
# Certbot auto-renewal cron
#
echo "0 3 * * * root certbot renew --quiet --deploy-hook 'docker exec mirror angie -s reload'" \
  > /etc/cron.d/certbot-mirror
