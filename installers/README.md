# NETOPT Installers

This directory contains all installation methods and related files for NETOPT.

## Directory Structure

```
installers/
├── install-smart.sh                    # Recommended: Smart installer with auto-detection
├── safe-install.sh                     # For remote sessions: 10s delay protection
├── install-network-optimize.sh         # Legacy: Original installer
├── systemd/                            # Enhanced systemd service files
│   ├── netopt-enhanced.service         # Standard service with health checks
│   └── netopt-verbose.service          # Verbose logging service
└── legacy/                             # Legacy systemd files (v1.0)
    ├── network-optimize.service
    ├── network-optimize-periodic.service
    └── network-optimize.timer
```

## Installation Methods

### 1. Smart Installer (Recommended)

**Use when:** First-time installation on any system

```bash
./installers/install-smart.sh
```

**Features:**
- Automatic privilege detection (root/sudo/user)
- Interactive wizard with 3 modes (automatic/custom/advanced)
- Dependency installation
- Configuration file creation
- Systemd service setup (system or user mode)
- Initial checkpoint creation
- Detailed installation report
- Post-installation verification

**Installs to:**
- Root mode: `/opt/netopt`, `/etc/netopt`, `/usr/local/bin/netopt`
- User mode: `~/.local/share/netopt`, `~/.config/netopt`, `~/.local/bin/netopt`
- Portable mode: `~/.netopt`

---

### 2. Safe Installer (Remote Sessions)

**Use when:** Installing via SSH/remote session

```bash
./installers/safe-install.sh
```

**Features:**
- 10-second delay before applying changes
- Prevents SSH disconnection
- Legacy systemd integration
- Simple, proven method

**Safety:**
- Waits 10 seconds after you run it
- Your SSH session won't drop immediately
- Uses legacy service files (proven stable)

---

### 3. Legacy Installer (Original)

**Use when:** Need original v1.0 behavior

```bash
sudo ./installers/install-network-optimize.sh
```

**Features:**
- Original installation method from v1.0
- System-wide installation only
- Requires root access
- Simple and straightforward
- Uses legacy service files

**Note:** Does not include new features (checkpoints, watchdog, BGP, etc.)

---

### 4. Manual Run (No Installation)

**Use when:** Testing or one-time optimization

```bash
sudo ./network-optimize.sh
```

**Features:**
- No installation required
- Run directly from source
- Portable mode
- Full functionality

---

## Orchestrator Script

The root `./install` script provides a menu to select the appropriate installer:

```bash
./install
```

**Features:**
- System detection (OS, privileges, systemd)
- Installer recommendation based on system
- Interactive menu
- Prerequisite checking
- Automatic selection of best installer

---

## Systemd Services

### Enhanced Services (Recommended)

Located in `installers/systemd/`:

**netopt-enhanced.service:**
- Pre-flight validation checks
- Automatic checkpoint creation
- Post-execution validation
- Auto-rollback on failure
- Resource limits and security hardening

**netopt-verbose.service:**
- All features from enhanced service
- 5-phase detailed logging
- Network state capture (before/after)
- Performance metrics
- JSON structured logging
- Comprehensive validation (4 tests)

### Legacy Services (v1.0 Compatible)

Located in `installers/legacy/`:

**network-optimize.service:**
- Simple one-shot service
- Runs at boot
- Basic restart on failure

**network-optimize-periodic.service:**
- Periodic re-optimization

**network-optimize.timer:**
- Triggers every 5 minutes
- Persistent across reboots

---

## Installation Comparison

| Feature | Smart | Safe | Legacy | Manual |
|---------|-------|------|--------|--------|
| **Auto-detection** | ✓ | - | - | - |
| **Multiple modes** | ✓ | - | - | - |
| **User install** | ✓ | - | - | ✓ |
| **Dependency install** | ✓ | ✓ | ✓ | - |
| **Checkpoints** | ✓ | - | - | - |
| **Watchdog timer** | ✓ | - | - | - |
| **Installation report** | ✓ | - | - | - |
| **Remote safe** | ✓ | ✓ | - | - |
| **Enhanced service** | ✓ | - | - | - |
| **Requires root** | No* | Yes | Yes | Yes |
| **Complexity** | Medium | Low | Low | None |

*Can install in user mode without root

---

## Which Installer Should I Use?

### Choose Smart Installer if:
- ✓ First-time installation
- ✓ Want full features (BGP, checkpoints, monitoring)
- ✓ Need user-mode installation option
- ✓ Want detailed installation report
- ✓ Prefer guided installation

### Choose Safe Installer if:
- ✓ Installing via SSH
- ✓ Worried about disconnection
- ✓ Want proven, simple method
- ✓ Don't need advanced features

### Choose Legacy Installer if:
- ✓ Need v1.0 behavior
- ✓ Have scripts expecting old paths
- ✓ Want minimal changes to system
- ✓ Prefer original service files

### Choose Manual Run if:
- ✓ Just testing NETOPT
- ✓ One-time optimization
- ✓ Don't want system installation
- ✓ Running in development mode

---

## Post-Installation

### Verify Installation

```bash
# Check command available
command -v netopt

# Check service status (system)
systemctl status netopt.service

# Check service status (user)
systemctl --user status netopt.service

# View configuration
cat /etc/netopt/netopt.conf
# OR
cat ~/.config/netopt/netopt.conf
```

### Start Service

```bash
# System service
sudo systemctl start netopt.service

# User service
systemctl --user start netopt.service

# Manual run
sudo netopt --apply
```

### View Logs

```bash
# System service logs
sudo journalctl -u netopt -f

# User service logs
journalctl --user -u netopt -f

# File logs
cat /var/log/netopt/netopt.log
# OR
cat ~/.local/share/netopt/logs/netopt.log
```

---

## Uninstallation

### System Installation

```bash
# Stop and disable service
sudo systemctl stop netopt.service
sudo systemctl disable netopt.service

# Remove files
sudo rm -rf /opt/netopt
sudo rm -f /etc/systemd/system/netopt*.service
sudo rm -f /usr/local/bin/netopt
sudo rm -rf /etc/netopt
sudo rm -rf /var/log/netopt

# Reload systemd
sudo systemctl daemon-reload
```

### User Installation

```bash
# Stop and disable service
systemctl --user stop netopt.service
systemctl --user disable netopt.service

# Remove files
rm -rf ~/.local/share/netopt
rm -f ~/.config/systemd/user/netopt.service
rm -f ~/.local/bin/netopt
rm -rf ~/.config/netopt

# Reload systemd
systemctl --user daemon-reload
```

---

## Troubleshooting Installers

### "Permission denied" during installation

```bash
# Ensure running with appropriate privileges
sudo ./installers/install-smart.sh

# Or check if installer is executable
chmod +x installers/install-smart.sh
```

### "File not found" errors

```bash
# Ensure running from NETOPT root directory
cd /path/to/NETOPT
./install

# Or use absolute paths
/home/john/Downloads/NETOPT/install
```

### Installation fails with systemd errors

```bash
# Check systemd availability
systemctl --version

# Try user mode instead
# Select option 2 (Custom) → User service

# Or skip systemd
# Select option 3 (Custom) → Portable mode
```

### Installation succeeds but command not found

```bash
# Reload shell configuration
source ~/.bashrc

# Or add to PATH manually
export PATH="$HOME/.local/bin:$PATH"

# Check installation location
which netopt
```

---

## Support

For installation issues:
- See main documentation: [../README.md](../README.md)
- See installation guide: [../docs/INSTALLATION.md](../docs/INSTALLATION.md)
- Report issues: https://github.com/SWORDIntel/NETOPT/issues
