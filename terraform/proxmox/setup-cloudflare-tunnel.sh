#!/bin/bash
# Cloudflare Tunnel Setup Script for Homelab
# Run this on your tunnel host (can be any machine with internet access)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Setting up Cloudflare Tunnel for Homelab${NC}"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}❌ This script should not be run as root${NC}"
   exit 1
fi

# Install cloudflared
echo -e "${YELLOW}📦 Installing cloudflared...${NC}"
if ! command -v cloudflared &> /dev/null; then
    # Download and install cloudflared
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared-linux-amd64.deb
    rm cloudflared-linux-amd64.deb
    echo -e "${GREEN}✅ cloudflared installed${NC}"
else
    echo -e "${GREEN}✅ cloudflared already installed${NC}"
fi

# Create cloudflared user and directories
echo -e "${YELLOW}👤 Setting up cloudflared user...${NC}"
sudo useradd -r -s /bin/false -d /home/cloudflared cloudflared 2>/dev/null || true
sudo mkdir -p /home/cloudflared/.cloudflared
sudo chown -R cloudflared:cloudflared /home/cloudflared

# Check for Cloudflare credentials
if [ ! -f "/home/cloudflared/.cloudflared/cert.pem" ]; then
    echo -e "${YELLOW}🔐 Cloudflare authentication required${NC}"
    echo "Please run the following command to authenticate:"
    echo "sudo -u cloudflared cloudflared tunnel login"
    echo ""
    echo "Then create a tunnel:"
    echo "sudo -u cloudflared cloudflared tunnel create homelab"
    echo ""
    echo "After that, copy the tunnel config to /home/cloudflared/.cloudflared/config.yml"
    echo "and run this script again."
    exit 1
fi

# Copy configuration
if [ -f "cloudflare-tunnel-config.yaml" ]; then
    echo -e "${YELLOW}📝 Copying tunnel configuration...${NC}"
    sudo cp cloudflare-tunnel-config.yaml /home/cloudflared/.cloudflared/config.yml
    sudo chown cloudflared:cloudflared /home/cloudflared/.cloudflared/config.yml
    echo -e "${GREEN}✅ Configuration copied${NC}"
else
    echo -e "${RED}❌ cloudflare-tunnel-config.yaml not found${NC}"
    echo "Please ensure the config file is in the current directory"
    exit 1
fi

# Create systemd service
echo -e "${YELLOW}🔧 Creating systemd service...${NC}"
sudo tee /etc/systemd/system/cloudflared.service > /dev/null <<EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
User=cloudflared
ExecStart=/usr/local/bin/cloudflared tunnel --config /home/cloudflared/.cloudflared/config.yml run
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
echo -e "${YELLOW}🚀 Starting Cloudflare Tunnel service...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable cloudflared
sudo systemctl start cloudflared

# Check status
echo -e "${YELLOW}📊 Checking service status...${NC}"
if sudo systemctl is-active --quiet cloudflared; then
    echo -e "${GREEN}✅ Cloudflare Tunnel is running${NC}"
    echo ""
    echo "🌐 Your services should now be accessible via:"
    echo "  • Portainer: https://portainer.wally.dominiksiejak.pl"
    echo "  • AdGuard: https://adguard.wally.dominiksiejak.pl"
    echo "  • K3s: https://k3s.wally.dominiksiejak.pl"
    echo ""
    echo "📊 Monitor tunnel status:"
    echo "  sudo systemctl status cloudflared"
    echo "  sudo journalctl -u cloudflared -f"
else
    echo -e "${RED}❌ Cloudflare Tunnel failed to start${NC}"
    echo "Check logs: sudo journalctl -u cloudflared -n 50"
    exit 1
fi

echo -e "${GREEN}🎉 Cloudflare Tunnel setup complete!${NC}"
