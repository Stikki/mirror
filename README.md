# mirror

Self-hosted single-tunnel replacement for ngrok. Expose one local HTTP port through a cloud server you own.

## How it works

```
Browser ─HTTPS─> Angie (cloud) ─> 127.0.0.1:7000 (sshd reverse tunnel) ─> your laptop:LOCAL_PORT
```

Two components:

- **Server**: a container with Angie + sshd. Angie terminates TLS and proxies to a fixed loopback port that sshd binds via reverse-tunnel from the client.
- **Client**: a bash script (`bin/mirror`) that opens the SSH reverse tunnel.

Single tunnel, single hostname, no multi-tenancy.

## Server setup

On the cloud host:

```bash
cd server/
cp .env.example .env
# Edit MIRROR_HOST, etc.
cp ~/my-laptop.pub authorized_keys   # one or more SSH pubkeys, one per line

# If using TLS (MIRROR_TLS=auto), obtain cert first:
sudo certbot certonly --webroot -w /var/www/letsencrypt -d "$MIRROR_HOST"

docker compose up -d
docker compose logs -f
```

DNS: point `MIRROR_HOST` at the server's public IP.

## Client setup

On the laptop:

```bash
# One-time
mkdir -p ~/.config/mirror
cat > ~/.config/mirror/config <<EOF
MIRROR_HOST=mirror.example.com
MIRROR_USER=mirror
MIRROR_PORT=7000
MIRROR_SSH_PORT=2022
EOF

ln -s "$PWD/bin/mirror" ~/.local/bin/mirror

# Expose localhost:3000
mirror 3000
```

Ctrl-C to stop.

## Files

- `bin/mirror` — client script
- `server/Dockerfile` — Alpine + Angie + sshd
- `server/docker-compose.yml` — one-command deploy
- `server/rootfs/usr/local/bin/entrypoint.sh` — renders config, supervises daemons
- `server/rootfs/etc/angie/http.d/mirror.conf.template` — Angie server block (TLS)
- `server/rootfs/etc/angie/http.d/mirror.http.conf.template` — Angie server block (HTTP-only)
- `server/rootfs/etc/ssh/sshd_config` — hardened sshd config
