#!/bin/bash
# Installation script for Network Optimization Service

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Installing Network Optimization Service ==="

# 1. Copy main script to system location
echo "Installing main script..."
cp "$SCRIPT_DIR/network-optimize.sh" /usr/local/bin/network-optimize.sh
chmod +x /usr/local/bin/network-optimize.sh
echo "  ✓ Script installed to /usr/local/bin/network-optimize.sh"

# 2. Install systemd service files
echo "Installing systemd services..."
cp "$SCRIPT_DIR/network-optimize.service" /etc/systemd/system/
cp "$SCRIPT_DIR/network-optimize-periodic.service" /etc/systemd/system/
cp "$SCRIPT_DIR/network-optimize.timer" /etc/systemd/system/
echo "  ✓ Systemd files installed"

# 3. Reload systemd
echo "Reloading systemd daemon..."
systemctl daemon-reload
echo "  ✓ Systemd reloaded"

# 4. Enable services
echo "Enabling services..."
systemctl enable network-optimize.service
systemctl enable network-optimize.timer
echo "  ✓ Services enabled (will start on boot)"

# 5. Install dnsmasq if not present
echo "Checking for dnsmasq..."
if ! command -v dnsmasq &> /dev/null; then
    echo "  Installing dnsmasq..."

    # Detect package manager
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y dnsmasq
    elif command -v dnf &> /dev/null; then
        dnf install -y dnsmasq
    elif command -v yum &> /dev/null; then
        yum install -y dnsmasq
    elif command -v pacman &> /dev/null; then
        pacman -S --noconfirm dnsmasq
    else
        echo "  ⚠ Could not detect package manager. Please install dnsmasq manually."
    fi
fi

# 6. Configure dnsmasq
if command -v dnsmasq &> /dev/null; then
    echo "Configuring dnsmasq for DNS caching..."

    # Backup existing config
    [ -f /etc/dnsmasq.conf ] && cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup

    # Create optimized config
    cat > /etc/dnsmasq.d/network-optimize.conf <<'EOF'
# Network Optimize DNS Cache Configuration

# Listen only on localhost
listen-address=127.0.0.1

# Don't read /etc/hosts
no-hosts

# Use Cloudflare and Google DNS
server=1.1.1.1
server=1.0.0.1
server=8.8.8.8
server=8.8.4.4

# Cache settings
cache-size=10000
no-negcache

# Performance
dns-forward-max=1000

# Don't use /etc/resolv.conf for upstream servers
no-resolv

# DNSSEC
dnssec
trust-anchor=.,20326,8,2,E06D44B80B8F1D39A95C0B0D7C65D08458E880409BBC683457104237C7F8EC8D
EOF

    echo "  ✓ dnsmasq configured"

    # Configure NetworkManager to use dnsmasq
    if [ -d /etc/NetworkManager/conf.d ]; then
        cat > /etc/NetworkManager/conf.d/dns.conf <<'EOF'
[main]
dns=dnsmasq
EOF
        echo "  ✓ NetworkManager configured to use dnsmasq"
    fi

    # Enable and start dnsmasq
    systemctl enable dnsmasq
    systemctl restart dnsmasq

    # Restart NetworkManager
    systemctl restart NetworkManager

    echo "  ✓ dnsmasq enabled and started"
else
    echo "  ⚠ dnsmasq not installed, skipping DNS cache setup"
fi

echo ""
echo "=== Installation Complete! ==="
echo ""
echo "Services installed:"
echo "  • network-optimize.service - Runs once at boot"
echo "  • network-optimize.timer - Re-optimizes every 5 minutes"
echo ""
echo "Usage:"
echo "  Start now:           sudo systemctl start network-optimize.service"
echo "  Check status:        sudo systemctl status network-optimize.service"
echo "  View logs:           sudo journalctl -u network-optimize.service -f"
echo "  Manual run:          sudo /usr/local/bin/network-optimize.sh"
echo "  Restore routes:      sudo /usr/local/bin/network-optimize.sh --restore"
echo ""
echo "DNS Caching:"
if systemctl is-active --quiet dnsmasq 2>/dev/null; then
    echo "  ✓ dnsmasq is running - DNS queries cached locally"
    echo "  Test: dig google.com (should show 'SERVER: 127.0.0.1')"
else
    echo "  ⚠ dnsmasq not running - using upstream DNS directly"
fi
echo ""
echo "Would you like to start the service now? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "Starting network optimization..."
    systemctl start network-optimize.service
    echo ""
    echo "Current status:"
    systemctl status network-optimize.service --no-pager
fi
