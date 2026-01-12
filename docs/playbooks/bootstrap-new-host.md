# PB003: Bootstrap New Host

## Purpose

Set up a new server to run Docker workloads managed by this repository.

## Prerequisites

- [ ] Fresh OS installed (Ubuntu 22.04 LTS or Debian 12 recommended)
- [ ] SSH access with sudo privileges
- [ ] Network connectivity
- [ ] DNS/IP address assigned
- [ ] This repository cloned locally

## Estimated Time

1-2 hours (depending on network speed and complexity)

## Procedure

### 1. Initial Server Access

```bash
# SSH to the new server
ssh user@new-host

# Update system
sudo apt update && sudo apt upgrade -y

# Set hostname
sudo hostnamectl set-hostname <hostname>

# Set timezone
sudo timedatectl set-timezone Europe/Warsaw
```

### 2. Install Docker

```bash
# Install prerequisites
sudo apt install -y ca-certificates curl gnupg

# Add Docker's GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, then verify
docker --version
docker compose version
```

### 3. Configure Docker

```bash
# Create daemon config
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-address-pools": [
    {"base": "172.17.0.0/16", "size": 24}
  ]
}
EOF

# Restart Docker
sudo systemctl restart docker
```

### 4. Set Up SSH Key for Deployment

```bash
# On your local machine, copy SSH key
ssh-copy-id user@new-host

# Add to SSH config (~/.ssh/config)
Host <hostname>
    HostName <ip-or-fqdn>
    User <user>
    IdentityFile ~/.ssh/id_ed25519
```

### 5. Create Directory Structure

```bash
# On the new host
sudo mkdir -p /opt/stacks
sudo chown $USER:$USER /opt/stacks

# Create traefik network
docker network create traefik
```

### 6. Sync Stacks from Repository

On your local machine:

```bash
cd terraform/portainer

# Update the rsync target in Makefile if needed
# Then sync
make sync-portainer
```

Or manually:

```bash
rsync -av --delete stacks/ <hostname>:/opt/stacks/
```

### 7. Set Up Environment Files

On the new host:

```bash
cd /opt/stacks

# For each stack that needs secrets
for dir in */; do
  if ls "$dir"*.env.example 1> /dev/null 2>&1; then
    echo "Stack $dir needs environment files:"
    ls "$dir"*.env.example
  fi
done

# Copy and edit each one
cp <stack>/<stack>.env.example <stack>/<stack>.env
vim <stack>/<stack>.env
```

### 8. Start Core Services

Start services in dependency order:

```bash
# 1. Traefik (reverse proxy)
cd /opt/stacks/traefik
docker compose up -d

# 2. PostgreSQL (if used)
cd /opt/stacks/postgres
docker compose up -d

# 3. Other services
cd /opt/stacks/<service>
docker compose up -d
```

### 9. Configure DNS

Add DNS records pointing to the new host:

- A record: `*.new-host.domain.com` → `<ip>`
- Or individual records for each service

If using RouterOS (managed by Terraform):

```bash
cd terraform/routeros
# Update DNS entries in dns.tf
make plan
make apply
```

### 10. Verify Services

```bash
# Check all containers are running
docker ps

# Check Traefik dashboard
curl -I https://traefik.<domain>/dashboard/

# Check each service
curl -I https://<service>.<domain>/
```

## Post-Bootstrap

- [ ] Add host to monitoring (Uptime Kuma)
- [ ] Configure backups
- [ ] Add to NetBox inventory
- [ ] Update documentation
- [ ] Set up log aggregation (if applicable)

## Rollback

If the new host isn't working:

1. Point DNS back to old host
2. Investigate issues on new host
3. Don't decommission old host until new one is stable

## Security Hardening (Optional)

```bash
# Disable password auth
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# Set up firewall
sudo apt install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw enable

# Install fail2ban
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Docker won't start | Check `journalctl -u docker` |
| Containers can't reach internet | Check Docker DNS, try `--dns 8.8.8.8` |
| Traefik not routing | Ensure containers are on `traefik` network |
| SSL errors | Check Let's Encrypt rate limits, verify DNS |

