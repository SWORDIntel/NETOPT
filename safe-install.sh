#!/bin/bash
# Safe installation wrapper for remote sessions
# This schedules the network changes to run after you disconnect

echo "=== Safe Network Optimization Installer ==="
echo ""
echo "This will install and run the network optimizer safely."
echo ""
echo "⚠️  IMPORTANT: If you're connected remotely (SSH/VNC), the network"
echo "    will be briefly interrupted. The script will:"
echo ""
echo "    1. Wait 10 seconds after you run this"
echo "    2. Apply network optimization"
echo "    3. Your connection may drop briefly but will reconnect"
echo ""
echo "Files to be installed:"
echo "  • /usr/local/bin/network-optimize.sh"
echo "  • systemd services for auto-run on boot"
echo "  • dnsmasq for DNS caching"
echo "  • Periodic re-optimization every 5 minutes"
echo ""
read -p "Continue with installation? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 1
fi

# Check if we're root
if [ "$EUID" -ne 0 ]; then
    echo "Re-running with sudo..."
    sudo "$0" "$@"
    exit $?
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run the main installer
bash "$SCRIPT_DIR/install-network-optimize.sh"

echo ""
echo "=== Installation Complete ==="
echo ""
echo "The service is now installed. To activate safely:"
echo ""
echo "Option 1 - Delayed start (safe for remote sessions):"
echo "  echo 'systemctl start network-optimize.service' | at now + 1 minute"
echo ""
echo "Option 2 - Start on next boot:"
echo "  Just reboot - it will start automatically"
echo ""
echo "Option 3 - Start immediately (may disconnect you if remote):"
echo "  systemctl start network-optimize.service"
echo ""
read -p "Start optimization now with 10-second delay? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Scheduling network optimization in 10 seconds..."
    echo "You may disconnect briefly but will reconnect automatically."
    sleep 2

    # Schedule with 'at' if available, otherwise use background process
    if command -v at &> /dev/null; then
        echo "systemctl start network-optimize.service" | at now + 10 seconds 2>/dev/null
        echo "✓ Scheduled via 'at' command"
    else
        # Fallback: use background process
        (sleep 10 && systemctl start network-optimize.service) &
        echo "✓ Scheduled via background process"
    fi

    echo ""
    echo "Network optimization will begin in 10 seconds..."
    echo "Check logs after reconnecting: journalctl -u network-optimize.service -f"
fi
