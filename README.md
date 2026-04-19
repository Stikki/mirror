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

Prerequisites: Terraform installed, AWS credentials configured, image pushed to GHCR.

Push to `main` to trigger the GitHub Actions build, or run manually:

```bash
gh workflow run build.yml
```

Then deploy the infrastructure:

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set mirror_authorized_key to your pubkey
terraform init
terraform plan
terraform apply
```

Terraform creates the EC2 instance, Elastic IP, and Route53 DNS record. The instance pulls the image from GHCR on first boot via cloud-init.

## Updating production

After pushing changes to `main` and the GHCR image is rebuilt:

```bash
ssh ec2-user@mirror.stikki.ninja 'cd /opt/mirror/deploy && sudo docker compose pull && sudo docker compose up -d'
```

## Client setup

```bash
mkdir -p ~/.config/mirror
cat > ~/.config/mirror/config <<EOF
MIRROR_HOST=mirror.stikki.ninja
MIRROR_USER=mirror
MIRROR_PORT=7000
MIRROR_SSH_PORT=2222
MIRROR_SSH_KEY=~/.ssh/your-key
EOF

ln -s "$PWD/bin/mirror" ~/.local/bin/mirror

# Expose localhost:3000
mirror 3000
```

Ctrl-C to stop.

## Local development

Build the image (use `--no-cache` after changing `rootfs/` files):

```bash
cd server/
cp ~/.ssh/your-key.pub authorized_keys
sudo MIRROR_HOST=localhost MIRROR_TLS=off MIRROR_HTTP_PORT=8888 docker compose build --no-cache
```

Start the container:

```bash
sudo MIRROR_HOST=localhost MIRROR_TLS=off MIRROR_HTTP_PORT=8888 docker compose up
```

Note: env vars must go after `sudo`, not before — sudo drops the environment.

Configure the client for local testing (`~/.config/mirror/config`):

```
MIRROR_HOST=localhost
MIRROR_USER=mirror
MIRROR_PORT=7000
MIRROR_SSH_PORT=2222
MIRROR_SSH_KEY=~/.ssh/your-key
```

Open the tunnel and test:

```bash
bin/mirror 3000
curl http://localhost:8888
```

## Structure

```
bin/
  mirror                              client script
server/
  Dockerfile                          Alpine + Angie + sshd
  docker-compose.yml                  local dev (builds image)
  rootfs/
    etc/angie/templates/              Angie config templates (TLS + HTTP-only)
    etc/ssh/sshd_config               hardened sshd config
    usr/local/bin/entrypoint.sh       renders config, supervises daemons
deploy/
  docker-compose.yml                  production (pulls from GHCR)
  .env.example                        production env vars
terraform/
  main.tf, ec2.tf, dns.tf, ...       AWS infra (EC2, EIP, Route53)
  variables.tf                        input variables
  terraform.tfvars.example            example values
  templates/userdata.sh.tpl           EC2 cloud-init script
.github/workflows/
  build.yml                           builds and pushes image to GHCR
```
