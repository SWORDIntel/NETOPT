# NETOPT Installation Quick Reference

## One-Line Install

```bash
git clone https://github.com/SWORDIntel/NETOPT.git && cd NETOPT && ./install
```

---

## Installation Wizard (./install)

The `./install` orchestrator provides an interactive menu:

```
╔══════════════════════════════════════════════════════════════════════════╗
║            Network Optimization Toolkit - Installer                     ║
╚══════════════════════════════════════════════════════════════════════════╝

System Information:
  OS: Linux 6.16.9+deb14-amd64
  Distribution: Debian GNU/Linux 12 (bookworm)
  Privileges: Sudo (passwordless)
  systemd: Available (version 252)

Available Installation Methods:

1. Smart Installer (Recommended)
   - Interactive wizard with automatic detection
   - Full features and safety mechanisms
   - Creates systemd service
   Script: installers/install-smart.sh

2. Safe Installer (For Remote Sessions)
   - 10-second delay before applying
   - Prevents SSH disconnection
   Script: installers/safe-install.sh

3. Legacy Installer (Original Version)
   - v1.0 compatible
   - Basic functionality
   Script: installers/install-network-optimize.sh

4. Manual Run (No Installation)
   - Run directly without installation
   Script: ./network-optimize.sh

5. Exit

Select installation method [1-5]:
```

---

## Quick Decision Guide

### I want the best experience → **Option 1** (Smart Installer)
- Full features (BGP, checkpoints, monitoring)
- Automatic configuration
- Detailed feedback

### I'm connected via SSH → **Option 2** (Safe Installer)
- 10-second delay protects from disconnection
- Simple and proven

### I need v1.0 behavior → **Option 3** (Legacy Installer)
- Original functionality
- Backward compatible

### I'm just testing → **Option 4** (Manual Run)
- No installation needed
- Run and forget

---

## What Gets Installed

### Smart Installer (Option 1)

**System Mode (root/sudo):**
```
/opt/netopt/                    # Installation directory
  ├─ netopt.sh                  # Main script
  ├─ lib/                       # 11 library modules
  ├─ logs/                      # Log files
  └─ checkpoints/               # System snapshots

/etc/netopt/                    # Configuration
  └─ netopt.conf

/usr/local/bin/                 # Commands
  └─ netopt -> /opt/netopt/netopt.sh

/etc/systemd/system/            # Services
  └─ netopt.service
```

**User Mode (no sudo):**
```
~/.local/share/netopt/          # Installation directory
~/.config/netopt/               # Configuration
~/.local/bin/netopt             # Command
~/.config/systemd/user/         # User service
```

**Portable Mode:**
```
~/.netopt/                      # Everything in one directory
```

---

## Post-Installation

### Start Optimization

**System installation:**
```bash
sudo systemctl start netopt.service
```

**User installation:**
```bash
systemctl --user start netopt.service
```

**Manual:**
```bash
sudo netopt --apply
```

### View Logs

**System:**
```bash
sudo journalctl -u netopt -f
```

**User:**
```bash
journalctl --user -u netopt -f
```

**File:**
```bash
cat /var/log/netopt/netopt.log
```

### Check Status

```bash
systemctl status netopt.service
# OR
systemctl --user status netopt.service
```

---

## Uninstall

The installer will create an uninstall script during installation:

```bash
# System
sudo /opt/netopt/uninstall.sh

# User
~/.local/share/netopt/uninstall.sh
```

Or manual cleanup:

```bash
# System
sudo systemctl stop netopt.service
sudo systemctl disable netopt.service
sudo rm -rf /opt/netopt /etc/netopt /usr/local/bin/netopt
sudo rm /etc/systemd/system/netopt.service
sudo systemctl daemon-reload

# User
systemctl --user stop netopt.service
systemctl --user disable netopt.service
rm -rf ~/.local/share/netopt ~/.config/netopt ~/.local/bin/netopt
rm ~/.config/systemd/user/netopt.service
systemctl --user daemon-reload
```

---

## Troubleshooting Installation

### Command not found after installation

```bash
# Reload shell
source ~/.bashrc

# Or manually add to PATH
export PATH="$HOME/.local/bin:$PATH"
```

### Permission denied

```bash
# Use sudo for system installation
sudo ./install

# Or select user mode (option 1, then custom, then user service)
./install
```

### Missing dependencies

```bash
# Install on Debian/Ubuntu
sudo apt-get install iproute2 systemd iputils-ping

# Install on RHEL/Fedora
sudo dnf install iproute systemd iputils

# Install on Arch
sudo pacman -S iproute2 systemd iputils
```

### Installer crashes

```bash
# Check prerequisites first
bash --version  # Should be 4.0+
ip -V           # Should be available

# Run with debug output
bash -x ./install
```

---

## Advanced Installation

### Custom Configuration During Install

```bash
# Set environment variables before installing
export NETOPT_PRIORITY_ETHERNET=5
export NETOPT_MAX_LATENCY=100
export NETOPT_ENABLE_BGP=1

./install
```

### Install to Custom Location

```bash
# Edit installers/install-smart.sh or use portable mode
./install
# Select: 1 (Smart) → 3 (Advanced) → 3 (Portable)
# Then manually move ~/.netopt to desired location
```

### Skip systemd Integration

```bash
# Use portable mode
./install
# Select: 1 (Smart) → 2 (Custom) → 3 (Portable)
```

---

## Verification

After installation, verify everything works:

```bash
# 1. Command available
command -v netopt && echo "✓ Command found" || echo "✗ Command not found"

# 2. Configuration exists
[[ -f /etc/netopt/netopt.conf ]] && echo "✓ Config found (system)" || \
[[ -f ~/.config/netopt/netopt.conf ]] && echo "✓ Config found (user)" || \
echo "✗ Config not found"

# 3. Service installed
systemctl list-unit-files netopt.service >/dev/null 2>&1 && echo "✓ Service found" || \
echo "⚠ Service not found (portable mode?)"

# 4. Library modules present
[[ -d /opt/netopt/lib ]] && echo "✓ Libraries found (system)" || \
[[ -d ~/.local/share/netopt/lib ]] && echo "✓ Libraries found (user)" || \
echo "⚠ Libraries not found"

# 5. Test run
sudo netopt --apply --dry-run && echo "✓ Dry-run successful" || echo "✗ Dry-run failed"
```

---

## Support

- **Full Documentation:** [README.md](README.md)
- **Installation Guide:** [docs/INSTALLATION.md](docs/INSTALLATION.md)
- **Installers Guide:** [installers/README.md](installers/README.md)
- **Issues:** https://github.com/SWORDIntel/NETOPT/issues

---

**Last Updated:** 2025-10-03
**Repository:** https://github.com/SWORDIntel/NETOPT
