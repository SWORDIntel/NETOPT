# NETOPT Safety Features - Quick Reference

## Installation

```bash
# Automatic (recommended)
./install-smart.sh

# The installer will detect:
# - Your privilege level (root/sudo/user)
# - Available installation modes
# - System capabilities
```

---

## Installation Modes

| Mode | Privilege | Install Path | Service | Use Case |
|------|-----------|--------------|---------|----------|
| **Root** | sudo/root | `/opt/netopt` | systemd system | Production servers |
| **User** | user | `~/.local/share/netopt` | systemd --user | Workstations |
| **Portable** | user | `~/.netopt` | None | Testing/dev |

---

## Checkpoint System

### Create Checkpoint
```bash
# Named checkpoint
/opt/netopt/lib/safety/checkpoint.sh create baseline "Initial system state"

# Auto-named
/opt/netopt/lib/safety/checkpoint.sh create auto
```

### List Checkpoints
```bash
/opt/netopt/lib/safety/checkpoint.sh list
```

### Restore Checkpoint
```bash
# Interactive restore (asks for confirmation)
/opt/netopt/lib/safety/checkpoint.sh restore baseline_20250103_120000

# Shows checkpoint details before restoring
# Creates pre-restore backup automatically
```

### Compare Checkpoints
```bash
/opt/netopt/lib/safety/checkpoint.sh compare checkpoint1 checkpoint2
```

### Cleanup Old Checkpoints
```bash
# Removes checkpoints beyond retention limit
/opt/netopt/lib/safety/checkpoint.sh cleanup
```

---

## Remote Safety (SSH Watchdog)

### Auto-Detect and Execute Safely
```bash
# Execute with default 5-minute timeout
/opt/netopt/lib/safety/remote-safe.sh execute "./network-optimize.sh --apply"

# Custom timeout (10 minutes)
/opt/netopt/lib/safety/remote-safe.sh execute "./network-optimize.sh --apply" 600

# Will:
# 1. Detect if you're in SSH session
# 2. Create safety checkpoint
# 3. Start watchdog timer
# 4. Execute command
# 5. Test connectivity
# 6. Ask for confirmation
# 7. Auto-rollback if timeout expires
```

### Manual Watchdog Control
```bash
# Start watchdog (5 minutes)
/opt/netopt/lib/safety/remote-safe.sh start 300

# Make your changes manually...

# Confirm changes (cancels watchdog)
/opt/netopt/lib/safety/remote-safe.sh confirm

# Or cancel watchdog
/opt/netopt/lib/safety/remote-safe.sh cancel
```

### Check Status
```bash
/opt/netopt/lib/safety/remote-safe.sh status
```

### Extend Timer
```bash
# Add 5 more minutes
/opt/netopt/lib/safety/remote-safe.sh extend 300
```

---

## Enhanced systemd Service

### Basic Usage
```bash
# Start with health checks
sudo systemctl start netopt-enhanced.service

# Check status
sudo systemctl status netopt-enhanced.service

# Enable on boot
sudo systemctl enable netopt-enhanced.service

# View logs
sudo journalctl -u netopt-enhanced.service -f
```

### What It Does Automatically
1. **Pre-flight checks:**
   - Verifies network interfaces are up
   - Tests gateway connectivity
   - Validates required commands

2. **Creates checkpoint** before changes

3. **Executes** optimizations safely

4. **Post-validation:**
   - Waits 2 seconds
   - Tests connectivity (3 pings)
   - Auto-rollback if failed

---

## Safety Workflow Examples

### Example 1: Safe Remote Optimization

```bash
# SSH into server
ssh user@server

# Execute with safety
/opt/netopt/lib/safety/remote-safe.sh execute "sudo systemctl start netopt.service" 600

# Output will show:
# - Session type detected (SSH)
# - Pre-flight checks
# - Watchdog started (timeout: 600s)
# - Network changes applied
# - Connectivity test
# - Confirmation prompt

# If everything works:
# → Type 'y' to confirm

# If connection lost:
# → Watchdog auto-rolls back after timeout
```

### Example 2: Manual Testing with Checkpoints

```bash
# Create baseline
/opt/netopt/lib/safety/checkpoint.sh create test1 "Before changes"

# Make changes
./network-optimize.sh --apply

# Test the changes
# ... testing ...

# If good, create new checkpoint
/opt/netopt/lib/safety/checkpoint.sh create test2 "After successful changes"

# If bad, restore
/opt/netopt/lib/safety/checkpoint.sh restore test1_*
```

### Example 3: Service Installation

```bash
# Run smart installer
./install-smart.sh

# Select:
# 1. Automatic (or)
# 2. Custom (choose your mode)
# 3. Advanced (configure everything)

# After installation:
sudo systemctl start netopt-enhanced.service
sudo systemctl status netopt-enhanced.service
```

---

## Emergency Recovery

### If You Get Locked Out (SSH)

The watchdog will automatically rollback after the timeout (default: 5 minutes).

**What happens:**
1. Timer expires
2. Emergency rollback script executes
3. Resets traffic control on all interfaces
4. Restores critical sysctl parameters
5. Logs rollback to syslog

### Manual Emergency Rollback

```bash
# If you still have access:

# Quick restore
./network-optimize.sh --restore

# Or from checkpoint
/opt/netopt/lib/safety/checkpoint.sh list
/opt/netopt/lib/safety/checkpoint.sh restore <latest_checkpoint>

# Or stop service
sudo systemctl stop netopt.service
```

---

## Configuration

### Main Config File Locations

**System (root mode):**
```
/etc/netopt/netopt.conf
```

**User mode:**
```
~/.config/netopt/netopt.conf
```

**Portable mode:**
```
~/.netopt/config/netopt.conf
```

### Key Configuration Options

```bash
# Safety features
ENABLE_CHECKPOINTS=true
CHECKPOINT_RETENTION=10        # Keep last 10 checkpoints
ENABLE_WATCHDOG=true
WATCHDOG_TIMEOUT=300           # 5 minutes

# Optimization
DEFAULT_PROFILE=balanced       # conservative|balanced|aggressive

# Logging
LOG_LEVEL=info                 # debug|info|warning|error

# Auto-apply
AUTO_APPLY_ON_BOOT=true
```

---

## Checkpoint Contents

Each checkpoint includes:

- Network interface state (`ip addr`, `ip route`, `ip link`)
- ethtool settings (features, ring buffers, coalescing)
- Traffic control (qdisc, class, filter)
- All sysctl parameters (net.*, kernel.*, vm.*)
- Kernel module states and parameters
- systemd service status
- Performance metrics (/proc/cpuinfo, meminfo, net/*)
- Firewall rules (iptables, nftables, firewalld)
- Metadata (timestamp, hostname, kernel, user)

Stored as compressed tar.gz archives.

---

## Remote Safety Detection

Automatically detects:

- `$SSH_CONNECTION` environment variable
- `$SSH_CLIENT` environment variable
- `$SSH_TTY` terminal type
- Remote login via `who am i`
- TMUX sessions
- Screen sessions

---

## Return Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Permission denied |
| 3 | Missing dependency |
| 4 | Configuration error |
| 5 | Checkpoint/restore failed |

---

## Best Practices

1. **Always create checkpoints** before making changes
2. **Use remote safety** when connected via SSH
3. **Test in dev** before production
4. **Monitor logs** during first deployment
5. **Keep checkpoints** for at least a week
6. **Review configurations** before enabling auto-boot
7. **Document changes** in checkpoint descriptions
8. **Test rollback** before relying on it

---

## Troubleshooting Quick Fixes

**Command not found:**
```bash
source ~/.bashrc
# or
export PATH="$HOME/.local/bin:$PATH"
```

**Permission denied:**
```bash
sudo <command>  # For system-wide
# or
chmod +x <script>  # For user scripts
```

**Service won't start:**
```bash
sudo journalctl -xeu netopt-enhanced.service
sudo systemctl daemon-reload
```

**Checkpoint directory full:**
```bash
/opt/netopt/lib/safety/checkpoint.sh cleanup
```

**Watchdog not canceling:**
```bash
rm -f /tmp/netopt-watchdog.*
```

---

## Files Reference

| File | Purpose |
|------|---------|
| `install-smart.sh` | Main installer entry point |
| `lib/installer/smart-install.sh` | Installation logic |
| `lib/safety/checkpoint.sh` | Checkpoint management |
| `lib/safety/remote-safe.sh` | Remote safety/watchdog |
| `systemd/netopt-enhanced.service` | Enhanced service |
| `docs/INSTALLATION.md` | Full documentation |

---

## Quick Command Summary

```bash
# Installation
./install-smart.sh

# Checkpoints
lib/safety/checkpoint.sh create <name> [desc]
lib/safety/checkpoint.sh list
lib/safety/checkpoint.sh restore <id>

# Remote Safety
lib/safety/remote-safe.sh execute <cmd> [timeout]
lib/safety/remote-safe.sh start [timeout]
lib/safety/remote-safe.sh confirm

# Service
sudo systemctl start netopt-enhanced.service
sudo systemctl status netopt-enhanced.service
sudo journalctl -u netopt-enhanced.service -f

# Status
netopt --status
netopt --show

# Apply/Restore
netopt --apply
netopt --restore
```

---

**For full documentation, see:** `docs/INSTALLATION.md`
