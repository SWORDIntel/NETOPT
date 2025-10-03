# NETOPT Installation Guide

Complete installation guide for the Network Optimization Toolkit with advanced safety features.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Installation Modes](#installation-modes)
3. [System Requirements](#system-requirements)
4. [Installation Options](#installation-options)
5. [Safety Features](#safety-features)
6. [Configuration](#configuration)
7. [Verification](#verification)
8. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Automatic Installation

The fastest way to install NETOPT:

```bash
cd /path/to/NETOPT
chmod +x install-smart.sh
./install-smart.sh
```

The installer will automatically:
- Detect your privilege level (root/user/portable)
- Choose the appropriate installation mode
- Configure all necessary components
- Enable safety features
- Create initial system checkpoint

### Manual Installation

For more control over the installation:

```bash
./install-smart.sh
# Select option 2 (Custom) or 3 (Advanced)
```

---

## Installation Modes

NETOPT supports three installation modes, automatically selected based on your privileges:

### 1. System-Wide Installation (Root Mode)

**Requirements:** Root access or sudo privileges

**Installation Paths:**
- Binaries: `/opt/netopt`
- Configuration: `/etc/netopt`
- Services: `/etc/systemd/system`
- Command: `/usr/local/bin/netopt`

**Features:**
- System-wide network optimizations
- Full hardware access
- Automatic boot integration
- All features enabled

**Installation:**
```bash
sudo ./install-smart.sh
```

### 2. User Service Installation (systemd-user Mode)

**Requirements:** systemd user session support

**Installation Paths:**
- Binaries: `~/.local/share/netopt`
- Configuration: `~/.config/netopt`
- Services: `~/.config/systemd/user`
- Command: `~/.local/bin/netopt`

**Features:**
- User-level optimizations
- No root required
- Automatic login integration
- Limited system-wide changes

**Installation:**
```bash
./install-smart.sh
# Installer will detect user mode automatically
```

### 3. Portable Installation

**Requirements:** None (fallback mode)

**Installation Paths:**
- Everything in: `~/.netopt`

**Features:**
- Fully portable
- No system integration
- Manual execution required
- Limited functionality

**Installation:**
```bash
./install-smart.sh
# Will use portable mode if systemd is unavailable
```

---

## System Requirements

### Minimum Requirements

- **OS:** Linux kernel 3.10+
- **Tools:** `bash`, `ip`, `sysctl`
- **Memory:** 64MB free
- **Disk:** 50MB free

### Recommended Requirements

- **OS:** Linux kernel 4.18+
- **Tools:** `bash`, `ip`, `tc`, `ethtool`, `sysctl`, `systemd`
- **Memory:** 128MB free
- **Disk:** 100MB free

### Optional Tools

- `iptables` - For firewall state management
- `nftables` - For modern firewall management
- `systemd` - For service integration
- `tar`, `gzip` - For checkpoint compression

---

## Installation Options

### Automatic Installation

Detects privileges and installs automatically:

```bash
./install-smart.sh
# Select option 1: Automatic
```

### Custom Installation

Choose installation mode manually:

```bash
./install-smart.sh
# Select option 2: Custom
# Choose: 1) System-wide, 2) User service, or 3) Portable
```

### Advanced Installation

Configure all options:

```bash
./install-smart.sh
# Select option 3: Advanced
```

**Configuration Options:**

1. **Installation Mode**
   - System-wide (root)
   - User service (systemd --user)
   - Portable (no systemd)

2. **Safety Features**
   - Automatic checkpoints (recommended)
   - Remote safety / SSH watchdog (recommended for servers)

3. **Optimization Profile**
   - Conservative (minimal changes, safest)
   - Balanced (recommended default)
   - Aggressive (maximum performance)

4. **Auto-apply on Boot**
   - Enable to apply optimizations automatically
   - Disable for manual control

---

## Safety Features

NETOPT includes comprehensive safety features to prevent network disruption:

### 1. Checkpoint System

**Purpose:** Create complete system state snapshots before changes

**Features:**
- Full network interface state capture
- Sysctl parameter backup
- Traffic control configuration
- Firewall rules backup
- Module state preservation

**Usage:**

```bash
# Create checkpoint
netopt --checkpoint create baseline "Initial state"

# List checkpoints
netopt --checkpoint list

# Restore checkpoint
netopt --checkpoint restore baseline_20250103_120000

# Delete checkpoint
netopt --checkpoint delete old_checkpoint
```

**Automatic Checkpoints:**
- Created before any optimization
- Created before service start
- Retained based on configuration (default: 10)

### 2. Remote Safety / SSH Watchdog

**Purpose:** Prevent network lockout during remote administration

**Features:**
- SSH session detection
- Automatic rollback timer
- Network connectivity monitoring
- Emergency rollback script

**How It Works:**

1. Detects SSH/remote session
2. Creates safety checkpoint
3. Starts watchdog timer (default: 5 minutes)
4. Applies optimizations
5. Tests network connectivity
6. Waits for user confirmation
7. Cancels watchdog if confirmed
8. Auto-rollback if timeout expires

**Usage:**

```bash
# Execute with safety (remote sessions only)
netopt --apply --safe

# Manual watchdog control
netopt --watchdog start 300  # Start 5-minute timer
# ... make changes ...
netopt --watchdog confirm    # Confirm changes

# Check watchdog status
netopt --watchdog status
```

**Configuration:**

Edit `/etc/netopt/netopt.conf`:

```bash
ENABLE_WATCHDOG=true
WATCHDOG_TIMEOUT=300  # seconds
```

### 3. Pre-flight Health Checks

**Purpose:** Verify system readiness before applying changes

**Checks:**
- Network interface status
- Gateway connectivity
- Required command availability
- Systemd service status
- Checkpoint system availability

**Automatic Execution:**
- Before service start
- Before optimization application
- During remote safety mode

### 4. Enhanced Systemd Service

**Purpose:** Robust service with health monitoring

**Features:**
- Pre-flight health checks
- Automatic checkpoint creation
- Post-execution validation
- Automatic rollback on failure
- Resource limits
- Security hardening

**Service File:** `/etc/systemd/system/netopt-enhanced.service`

**Usage:**

```bash
# Start with health checks
sudo systemctl start netopt-enhanced.service

# Check status
sudo systemctl status netopt-enhanced.service

# View logs
sudo journalctl -u netopt-enhanced.service -f
```

---

## Configuration

### Main Configuration File

**Location (by mode):**
- System: `/etc/netopt/netopt.conf`
- User: `~/.config/netopt/netopt.conf`
- Portable: `~/.netopt/config/netopt.conf`

**Example Configuration:**

```bash
# NETOPT Configuration File

# Installation paths
INSTALL_DIR=/opt/netopt
CONFIG_DIR=/etc/netopt
LOG_DIR=/opt/netopt/logs
CHECKPOINT_DIR=/opt/netopt/checkpoints

# Optimization levels
DEFAULT_PROFILE=balanced
# Options: conservative, balanced, aggressive

# Safety features
ENABLE_CHECKPOINTS=true
CHECKPOINT_RETENTION=10
ENABLE_WATCHDOG=true
WATCHDOG_TIMEOUT=300

# Logging
LOG_LEVEL=info
# Options: debug, info, warning, error

# Auto-apply on boot
AUTO_APPLY_ON_BOOT=true
```

### Optimization Profiles

#### Conservative Profile
- Minimal changes
- Safe for all systems
- Low risk
- Moderate performance gain

#### Balanced Profile (Default)
- Recommended settings
- Tested on various systems
- Medium risk
- Good performance gain

#### Aggressive Profile
- Maximum optimizations
- Requires testing
- Higher risk
- Maximum performance gain

**Change Profile:**

Edit configuration file:
```bash
DEFAULT_PROFILE=aggressive
```

Or use command line:
```bash
netopt --apply --profile aggressive
```

---

## Verification

### Post-Installation Checks

After installation, verify everything is working:

#### 1. Command Availability

```bash
# Check if netopt is in PATH
which netopt

# Test command
netopt --version
netopt --help
```

#### 2. Configuration File

```bash
# System-wide
cat /etc/netopt/netopt.conf

# User
cat ~/.config/netopt/netopt.conf

# Portable
cat ~/.netopt/config/netopt.conf
```

#### 3. Service Status

```bash
# System service
sudo systemctl status netopt.service

# User service
systemctl --user status netopt.service
```

#### 4. Checkpoint System

```bash
# Test checkpoint creation
netopt --checkpoint create test "Test checkpoint"

# List checkpoints
netopt --checkpoint list

# Delete test checkpoint
netopt --checkpoint delete test_*
```

#### 5. Safety Features

```bash
# Check remote safety
netopt --watchdog status

# Test safety execution (will skip if not remote)
netopt --apply --safe
```

### System Status

Check overall system status:

```bash
# View current optimizations
netopt --status

# View applied settings
netopt --show

# Check logs
tail -f /opt/netopt/logs/netopt.log
```

---

## Troubleshooting

### Common Issues

#### 1. Command Not Found

**Problem:** `netopt: command not found`

**Solutions:**

```bash
# Reload shell configuration
source ~/.bashrc

# Or restart shell
exec bash

# Check PATH
echo $PATH

# Add to PATH manually (portable mode)
export PATH="$HOME/.local/bin:$PATH"
```

#### 2. Permission Denied

**Problem:** Permission errors during execution

**Solutions:**

```bash
# System-wide: Use sudo
sudo netopt --apply

# User mode: Check file permissions
chmod +x ~/.local/share/netopt/netopt.sh

# Verify ownership
ls -la ~/.local/share/netopt/
```

#### 3. Service Not Starting

**Problem:** Systemd service fails to start

**Solutions:**

```bash
# Check service status
sudo systemctl status netopt.service

# View full logs
sudo journalctl -xeu netopt.service

# Verify service file
sudo systemctl cat netopt.service

# Reload systemd
sudo systemctl daemon-reload
```

#### 4. Checkpoint Creation Fails

**Problem:** Cannot create checkpoints

**Solutions:**

```bash
# Check checkpoint directory
ls -la /opt/netopt/checkpoints/

# Create directory if missing
sudo mkdir -p /opt/netopt/checkpoints
sudo chown $USER:$USER /opt/netopt/checkpoints

# Check disk space
df -h /opt/netopt/
```

#### 5. Watchdog Not Starting

**Problem:** Remote safety watchdog doesn't start

**Solutions:**

```bash
# Verify SSH session
echo $SSH_CONNECTION

# Check watchdog status
netopt --watchdog status

# Clean stale locks
rm -f /tmp/netopt-watchdog.*

# Enable in config
# Edit /etc/netopt/netopt.conf
ENABLE_WATCHDOG=true
```

### Debug Mode

Enable debug logging:

```bash
# Edit configuration
LOG_LEVEL=debug

# Run with verbose output
netopt --apply --verbose

# View debug logs
tail -f /opt/netopt/logs/netopt-debug.log
```

### Recovery

If optimizations cause issues:

```bash
# Quick restore
netopt --restore

# Restore from checkpoint
netopt --checkpoint list
netopt --checkpoint restore <checkpoint_id>

# Emergency rollback (if watchdog active)
netopt --watchdog cancel

# Manual reset
sudo systemctl stop netopt.service
sudo sysctl -p  # Restore original sysctls
```

### Getting Help

1. **Check Logs:**
   ```bash
   sudo journalctl -u netopt.service
   tail -f /opt/netopt/logs/netopt.log
   ```

2. **Verify Configuration:**
   ```bash
   cat /etc/netopt/netopt.conf
   ```

3. **Check System State:**
   ```bash
   netopt --status
   netopt --show
   ```

4. **Review Documentation:**
   - README.md
   - Man pages: `man netopt`
   - Service docs: `systemctl cat netopt.service`

---

## Advanced Topics

### Custom Installation Paths

Override default paths:

```bash
# Edit lib/installer/smart-install.sh
INSTALL_DIR="/custom/path"
CONFIG_DIR="/custom/config"
```

### Integration with Other Services

NETOPT can integrate with:
- NetworkManager
- systemd-networkd
- Docker networking
- Kubernetes CNI

### Performance Monitoring

Monitor optimization effects:

```bash
# Before optimization
netopt --benchmark > before.txt

# Apply optimizations
netopt --apply

# After optimization
netopt --benchmark > after.txt

# Compare results
diff before.txt after.txt
```

### Automated Deployment

For mass deployment:

```bash
# Unattended installation
./install-smart.sh --auto --profile balanced

# Ansible playbook
ansible-playbook netopt-deploy.yml

# Docker container
docker build -t netopt .
docker run --privileged netopt
```

---

## Uninstallation

### Complete Removal

```bash
# Stop and disable service
sudo systemctl stop netopt.service
sudo systemctl disable netopt.service

# Remove files
sudo rm -rf /opt/netopt
sudo rm -rf /etc/netopt
sudo rm /usr/local/bin/netopt
sudo rm /etc/systemd/system/netopt*.service

# Reload systemd
sudo systemctl daemon-reload

# Restore original settings
sudo sysctl -p
```

### User Installation Removal

```bash
# Stop service
systemctl --user stop netopt.service
systemctl --user disable netopt.service

# Remove files
rm -rf ~/.local/share/netopt
rm -rf ~/.config/netopt
rm ~/.local/bin/netopt

# Reload systemd
systemctl --user daemon-reload
```

---

## Appendix

### File Structure

```
/opt/netopt/                    # Installation directory
├── netopt.sh                   # Main script
├── lib/
│   ├── installer/
│   │   └── smart-install.sh    # Smart installer
│   └── safety/
│       ├── checkpoint.sh       # Checkpoint system
│       └── remote-safe.sh      # Remote safety
├── logs/                       # Log files
├── checkpoints/                # State backups
└── docs/                       # Documentation

/etc/netopt/                    # Configuration
└── netopt.conf                 # Main config

/etc/systemd/system/            # System services
├── netopt.service
└── netopt-enhanced.service
```

### Environment Variables

- `NETOPT_MODE` - Override installation mode
- `NETOPT_PROFILE` - Default optimization profile
- `NETOPT_SAFETY` - Enable/disable safety features
- `NETOPT_DEBUG` - Enable debug output

### Return Codes

- `0` - Success
- `1` - General error
- `2` - Permission denied
- `3` - Missing dependency
- `4` - Configuration error
- `5` - Checkpoint/restore failed

---

**Last Updated:** 2025-10-03
**Version:** 1.0.0
**Maintainer:** NETOPT Team
