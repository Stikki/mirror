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

## Deploy to AWS

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set mirror_authorized_key to your pubkey
terraform init
terraform plan
terraform apply
```

The image must exist on GHCR before deploying. Push to `main` to trigger the GitHub Actions build, or run `gh workflow run build.yml` manually.

## Local development

```bash
cd server/
cp ~/.ssh/your-key.pub authorized_keys
MIRROR_HOST=localhost MIRROR_TLS=off docker compose up --build
```

Then from another terminal:

```bash
ssh -N -p 2222 -i ~/.ssh/your-key -R 7000:localhost:3000 mirror@localhost
```

## Client setup

```bash
mkdir -p ~/.config/mirror
cat > ~/.config/mirror/config <<EOF
MIRROR_HOST=mirror.stikki.ninja
MIRROR_USER=mirror
MIRROR_PORT=7000
MIRROR_SSH_PORT=2222
EOF

ln -s "$PWD/bin/mirror" ~/.local/bin/mirror

# Expose localhost:3000
mirror 3000
```

Ctrl-C to stop.

## Structure

```
bin/mirror                  client script
server/
  Dockerfile                Alpine + Angie + sshd
  docker-compose.yml        local dev (builds image)
  rootfs/                   files copied into the image
deploy/
  docker-compose.yml        production (pulls from GHCR)
  .env.example              production env vars
terraform/
  *.tf                      AWS infra (EC2, EIP, Route53)
  templates/userdata.sh.tpl EC2 cloud-init script
.github/workflows/
  build.yml                 builds and pushes image to GHCR
```
