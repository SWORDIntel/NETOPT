# NETOPT Logging Guide

Complete guide to NETOPT's logging system, including installer feedback, service logs, and monitoring.

## Table of Contents
- [Overview](#overview)
- [Installer Logging](#installer-logging)
- [Service Logging](#service-logging)
- [Log Locations](#log-locations)
- [Log Levels](#log-levels)
- [Viewing Logs](#viewing-logs)
- [JSON Logging](#json-logging)
- [Troubleshooting](#troubleshooting)

---

## Overview

NETOPT provides comprehensive logging at every stage:

1. **Installation Phase**: Detailed progress tracking and change reports
2. **Service Execution**: Structured logging of all optimization steps
3. **Monitoring**: Continuous performance and health metrics
4. **Audit Trail**: JSON-formatted logs for external monitoring systems

---

## Installer Logging

### Features

The installer provides real-time feedback with:
- **Step-by-step progress** (e.g., "[3/10] Installing dependencies...")
- **Color-coded output** (success=green, warning=yellow, error=red)
- **Change tracking** (all files created/modified)
- **Before/After comparisons** (network state, TCP settings, routes)
- **Detailed installation report** (saved to `/tmp/netopt-install-report.txt`)

### Installation Output Example

```
    _   ____________  __________
   / | / / ____/_  __/ __ / __ \/_  __/
  /  |/ / __/   / / / / / / /_/ / / /
 / /|  / /___  / / / /_/ / ____/ / /
/_/ |_/_____/ /_/  \____/_/     /_/

Network Optimization Toolkit - Smart Installer

System Information:
  OS: Linux 6.16.9+deb14-amd64
  Hostname: your-hostname
  User: john (UID: 1000)
  Privileges: Sudo (passwordless)

[INFO] Checking system requirements...
✓ System requirements check passed

[1/10] Detecting execution context...
  Detected: User has passwordless sudo access
  Mode: root
  ✓ Complete

[2/10] Configuring installation paths...
  Install directory: /opt/netopt
  Config directory:  /etc/netopt
  Service directory: /etc/systemd/system
  Binary directory:  /usr/local/bin
  ✓ Complete

[3/10] Checking system capabilities...
  ✓ All required capabilities present
  ✓ Complete

[4/10] Creating installation directories...
  ✓ Created: /opt/netopt
  ✓ Created: /etc/netopt
  ✓ Created: /etc/systemd/system
  ✓ Created: /usr/local/bin
  ✓ Complete

[5/10] Installing dependencies...
  Detected package manager: apt
  ⟳ Installing iproute2 via apt...
  ✓ iproute2 (already installed)
  ⟳ Installing ethtool via apt...
  ✓ ethtool installed
  ✓ Complete

[6/10] Installing NETOPT files...
  ✓ Installed main script (7.0K)
  + Created directory: /opt/netopt/lib
  ✓ Installed library files
  ✓ Created command symlink
  ✓ Complete

[7/10] Installing systemd service...
  ✓ Service file created: /etc/systemd/system/netopt.service
  ✓ Service enabled (system mode)
  ✓ Complete

[8/10] Creating default configuration...
  ✓ Configuration created: /etc/netopt/netopt.conf
  ✓ Complete

[9/10] Running post-installation tasks...
  ✓ Initial checkpoint created
  ✓ Complete

[10/10] Verifying installation...
  ✓ Command 'netopt' is available
  ✓ Configuration found: /etc/netopt/netopt.conf
  ✓ System service installed
  ✓ Complete

╔═══════════════════════════════════════════════════════════════════╗
║                  INSTALLATION COMPLETE                            ║
╚═══════════════════════════════════════════════════════════════════╝

Installation Statistics:
  ✓ Files Created: 15
  ✓ Files Modified: 2
  ✓ Services Installed: 1
  ✓ Dependencies Installed: 1

Installation Details:
  Mode: root
  Location: /opt/netopt
  Config: /etc/netopt/netopt.conf

Services Available:
  ● netopt.service

Detailed report saved to: /tmp/netopt-install-report-20251003-143022.txt

Display detailed installation report? [y/N]
```

### Installation Report Contents

The full report (`/tmp/netopt-install-report.txt`) includes:

```
================================================================================
NETOPT INSTALLATION REPORT
================================================================================
Date: 2025-10-03 14:30:22
Hostname: your-hostname
User: john (UID: 1000)
Installation Mode: root

================================================================================
PATHS CONFIGURED
================================================================================
Installation Directory: /opt/netopt
Configuration Directory: /etc/netopt
Binary Directory: /usr/local/bin
Service Directory: /etc/systemd/system
Log Directory: /opt/netopt/logs
Checkpoint Directory: /opt/netopt/checkpoints

================================================================================
FILES CREATED (15 total)
================================================================================
  /opt/netopt/netopt.sh                                       [main script]
  /opt/netopt/lib/core/paths.sh                              [library]
  /opt/netopt/lib/core/config.sh                             [library]
  /opt/netopt/lib/core/logger.sh                             [library]
  /opt/netopt/lib/network/detection.sh                       [library]
  /opt/netopt/lib/network/testing-parallel.sh                [library]
  /opt/netopt/lib/safety/checkpoint.sh                       [library]
  /etc/netopt/netopt.conf                                    [configuration]
  /etc/systemd/system/netopt.service                         [service]
  /usr/local/bin/netopt                                      [symlink]
  ... (5 more files)

================================================================================
FILES MODIFIED (2 total)
================================================================================
  /etc/resolv.conf                                           (backed up)
  /etc/sysctl.conf                                           (TCP params)

================================================================================
SERVICES INSTALLED (1 total)
================================================================================
  netopt.service                                             [systemd]

================================================================================
DEPENDENCIES INSTALLED (1 total)
================================================================================
  ethtool                                                     (via apt)

================================================================================
VERIFICATION COMMANDS
================================================================================
# Check installation
ls -la /opt/netopt
cat /etc/netopt/netopt.conf

# Test network optimization
sudo netopt --apply --dry-run

# View current configuration
systemctl status netopt.service
```

---

## Service Logging

### Logging Phases

The service logs through 5 distinct phases:

#### **Phase 1: Pre-flight Checks** ✓
```
[2025-10-03 14:35:00] INFO: ============================================================
[2025-10-03 14:35:00] INFO: NETOPT Service Starting
[2025-10-03 14:35:00] INFO: ============================================================
[2025-10-03 14:35:00] INFO: Timestamp: 2025-10-03 14:35:00 UTC
[2025-10-03 14:35:00] INFO: Hostname: your-hostname
[2025-10-03 14:35:00] INFO: User: root
[2025-10-03 14:35:00] INFO: PID: 12345
[2025-10-03 14:35:00] INFO: ------------------------------------------------------------
[2025-10-03 14:35:00] INFO: ============================================================
[2025-10-03 14:35:00] INFO: Pre-flight Checks
[2025-10-03 14:35:00] INFO: ============================================================
[2025-10-03 14:35:00] INFO: Validating system state before optimization
[2025-10-03 14:35:00] INFO:   ✓ Network Interfaces (3 interfaces UP)
[2025-10-03 14:35:01] INFO:   ✓ Gateway Connectivity (192.168.1.1 reachable)
[2025-10-03 14:35:01] INFO:   ✓ Command: ip (/usr/sbin/ip)
[2025-10-03 14:35:01] INFO:   ✓ Command: ping (/usr/bin/ping)
[2025-10-03 14:35:01] INFO:   ✓ Command: sysctl (/usr/sbin/sysctl)
[2025-10-03 14:35:01] INFO:   ✓ Configuration File (/etc/netopt/netopt.conf)
[2025-10-03 14:35:01] INFO: ------------------------------------------------------------
[2025-10-03 14:35:01] INFO: Pre-flight Summary: 4 passed, 0 failed
[2025-10-03 14:35:01] INFO: All pre-flight checks passed
```

#### **Phase 2: Network State (BEFORE)** 📊
```
[2025-10-03 14:35:01] INFO: Network State (BEFORE):
[2025-10-03 14:35:01] INFO:   Active Interfaces: 3
[2025-10-03 14:35:01] INFO:     enp3s0           UP             192.168.1.50/24
[2025-10-03 14:35:01] INFO:     wlp2s0           UP             192.168.1.51/24
[2025-10-03 14:35:01] INFO:     lo               UNKNOWN        127.0.0.1/8
[2025-10-03 14:35:01] INFO:   Default Routes:
[2025-10-03 14:35:01] INFO:     default via 192.168.1.1 dev enp3s0 proto dhcp metric 100
[2025-10-03 14:35:01] INFO:   DNS Servers:
[2025-10-03 14:35:01] INFO:     nameserver 192.168.1.1
```

#### **Phase 3: Checkpoint Creation** 💾
```
[2025-10-03 14:35:02] INFO: Creating pre-optimization checkpoint...
[2025-10-03 14:35:02] INFO: ✓ Checkpoint created: service_20251003_143502
[2025-10-03 14:35:02] DEBUG:   Location: /opt/netopt/checkpoints/service_20251003_143502.tar.gz
```

#### **Phase 4: Optimization Execution** ⚡
```
[2025-10-03 14:35:03] INFO: ============================================================
[2025-10-03 14:35:03] INFO: Network Optimization
[2025-10-03 14:35:03] INFO: ============================================================
[2025-10-03 14:35:03] INFO: Executing network optimization...
[2025-10-03 14:35:03] INFO: Testing Interface: enp3s0 (ethernet) via 192.168.1.1
[2025-10-03 14:35:04] INFO:   ✓ ALIVE - Latency: 2ms, Weight: 40
[2025-10-03 14:35:04] INFO: Testing Interface: wlp2s0 (wifi) via 192.168.1.1
[2025-10-03 14:35:05] INFO:   ✓ ALIVE - Latency: 15ms, Weight: 18
[2025-10-03 14:35:05] INFO: Applying load-balanced route with 2 connection(s)
[2025-10-03 14:35:05] INFO:   Configuration: enp3s0(ethernet:2ms:w40) wlp2s0(wifi:15ms:w18)
[2025-10-03 14:35:05] INFO: ✓ Load balancing enabled successfully
[2025-10-03 14:35:05] DEBUG: TCP Optimization: tcp_congestion_control = bbr
[2025-10-03 14:35:05] DEBUG: TCP Optimization: tcp_fastopen = 3
[2025-10-03 14:35:05] DEBUG: TCP Optimization: rmem_max = 16777216
[2025-10-03 14:35:05] DEBUG: TCP Optimization: wmem_max = 16777216
[2025-10-03 14:35:05] INFO: ✓ TCP optimizations applied
[2025-10-03 14:35:05] DEBUG:   tcp_congestion_control: bbr
[2025-10-03 14:35:05] DEBUG:   tcp_fastopen: 3
[2025-10-03 14:35:05] DEBUG:   rmem_max: 16777216
[2025-10-03 14:35:05] DEBUG:   wmem_max: 16777216
[2025-10-03 14:35:06] INFO: ⏱ Network optimization completed in 3s
[2025-10-03 14:35:06] DEBUG: Performance: optimization_duration = 3s
```

#### **Phase 5: Post-Validation** ✅
```
[2025-10-03 14:35:06] INFO: ============================================================
[2025-10-03 14:35:06] INFO: Post-Execution Validation
[2025-10-03 14:35:06] INFO: ============================================================
[2025-10-03 14:35:06] INFO: Verifying network optimizations
[2025-10-03 14:35:06] INFO: Waiting 3 seconds for route stabilization...
[2025-10-03 14:35:09] INFO:   ✓ Multipath Route (2 nexthops)
[2025-10-03 14:35:11] INFO:   ✓ Gateway Connectivity (192.168.1.1 responds to ping)
[2025-10-03 14:35:13] INFO:   ✓ Internet Connectivity (8.8.8.8 reachable)
[2025-10-03 14:35:14] INFO:   ✓ DNS Resolution (DNS working)
[2025-10-03 14:35:14] INFO: Network State (AFTER):
[2025-10-03 14:35:14] INFO:   Active Interfaces: 3
[2025-10-03 14:35:14] INFO:     enp3s0           UP             192.168.1.50/24
[2025-10-03 14:35:14] INFO:     wlp2s0           UP             192.168.1.51/24
[2025-10-03 14:35:14] INFO:   Default Routes:
[2025-10-03 14:35:14] INFO:     default proto static metric 1024
[2025-10-03 14:35:14] INFO:       nexthop via 192.168.1.1 dev enp3s0 weight 40
[2025-10-03 14:35:14] INFO:       nexthop via 192.168.1.1 dev wlp2s0 weight 18
[2025-10-03 14:35:14] INFO: ============================================================
[2025-10-03 14:35:14] INFO: NETOPT Service Started Successfully
[2025-10-03 14:35:14] INFO: Active connections optimized and validated
[2025-10-03 14:35:14] INFO: ============================================================
```

---

## Log Locations

### Standard Logging

| Installation Mode | Log File Location | Journal Access |
|-------------------|-------------------|----------------|
| **System (root)** | `/var/log/netopt/netopt.log` | `journalctl -u netopt` |
| **User (systemd --user)** | `~/.local/share/netopt/logs/netopt.log` | `journalctl --user -u netopt` |
| **Portable** | `~/.netopt/logs/netopt.log` | N/A |

### Structured JSON Logs

| Type | Location | Format |
|------|----------|--------|
| **Service Events** | `/var/log/netopt/netopt.json` | JSON (one per line) |
| **Performance Metrics** | `/var/log/netopt/metrics.json` | JSON with timestamps |
| **Audit Trail** | `/var/log/netopt/audit.json` | JSON with user/session info |

### Installation Reports

| Type | Location | Retention |
|------|----------|-----------|
| **Install Report** | `/tmp/netopt-install-report-YYYYMMDD-HHMMSS.txt` | Manual cleanup |
| **System State (Before)** | `/tmp/netopt-state-before.txt` | Until installation complete |
| **System State (After)** | `/tmp/netopt-state-after.txt` | Until installation complete |

---

## Log Levels

### Available Levels

| Level | Priority | Use Case | Color |
|-------|----------|----------|-------|
| **DEBUG** | 0 | Detailed diagnostic information | Cyan |
| **INFO** | 1 | General informational messages | Green |
| **WARN** | 2 | Warning conditions, non-critical | Yellow |
| **ERROR** | 3 | Error conditions, operation failed | Red |
| **FATAL** | 4 | Fatal errors, service cannot continue | Bold Red |

### Setting Log Level

**Via Environment Variable:**
```bash
export NETOPT_LOG_LEVEL=DEBUG
sudo systemctl restart netopt
```

**Via Configuration File** (`/etc/netopt/netopt.conf`):
```bash
LOG_LEVEL=DEBUG
```

**Temporary Override:**
```bash
sudo NETOPT_LOG_LEVEL=DEBUG netopt --apply
```

---

## Viewing Logs

### Installer Logs

**During Installation:**
- Real-time output to terminal
- Color-coded for easy reading

**After Installation:**
```bash
# View installation report
cat /tmp/netopt-install-report-*.txt

# View before/after state comparison
cat /tmp/netopt-state-before.txt
cat /tmp/netopt-state-after.txt
```

### Service Logs

**Real-time Monitoring:**
```bash
# System service
sudo journalctl -u netopt -f

# User service
journalctl --user -u netopt -f

# With specific log level
journalctl -u netopt -p info -f
```

**Historical Logs:**
```bash
# Last 100 lines
journalctl -u netopt -n 100

# Since boot
journalctl -u netopt -b

# Since specific time
journalctl -u netopt --since "2025-10-03 14:00:00"

# Between times
journalctl -u netopt --since "14:00" --until "15:00"
```

**File-Based Logs:**
```bash
# View current log
cat /var/log/netopt/netopt.log

# View with tail (real-time)
tail -f /var/log/netopt/netopt.log

# View rotated logs
ls -lh /var/log/netopt/netopt.log.*
```

### Filtering Logs

**By Log Level:**
```bash
# Only errors
journalctl -u netopt -p err

# Warnings and above
journalctl -u netopt -p warning

# Info and above (default)
journalctl -u netopt -p info
```

**By Content:**
```bash
# Search for specific interface
journalctl -u netopt | grep "enp3s0"

# Search for failures
journalctl -u netopt | grep -i "fail\|error"

# Search for optimizations
journalctl -u netopt | grep "optimization"
```

**Export Logs:**
```bash
# Export to file
journalctl -u netopt --since today > netopt-logs-today.txt

# Export JSON format
journalctl -u netopt -o json > netopt-logs.json

# Export with timestamps
journalctl -u netopt -o short-iso > netopt-logs-iso.txt
```

---

## JSON Logging

### JSON Log Format

Each event is logged as a JSON object:

```json
{
  "timestamp": "2025-10-03T14:35:14.123Z",
  "level": "INFO",
  "message": "service: start - success",
  "service": "netopt",
  "hostname": "your-hostname",
  "pid": 12345,
  "event_type": "service",
  "event_action": "start",
  "event_result": "success",
  "phase": "complete"
}
```

### Querying JSON Logs

**Using jq:**
```bash
# Get all errors
jq 'select(.level=="ERROR")' /var/log/netopt/netopt.json

# Get interface metrics
jq 'select(.interface)' /var/log/netopt/netopt.json

# Calculate average latency
jq -s 'map(select(.latency_ms)) | map(.latency_ms | tonumber) | add / length' \
    /var/log/netopt/netopt.json

# Events in last hour
jq --arg time "$(date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%S')" \
    'select(.timestamp > $time)' /var/log/netopt/netopt.json
```

---

## Troubleshooting

### No Logs Appearing

**Check log file permissions:**
```bash
ls -la /var/log/netopt/
sudo chmod 755 /var/log/netopt
sudo touch /var/log/netopt/netopt.log
sudo chmod 644 /var/log/netopt/netopt.log
```

**Check service status:**
```bash
systemctl status netopt
```

**Check journal space:**
```bash
journalctl --disk-usage
# If full, clean old logs:
sudo journalctl --vacuum-time=7d
```

### Logs Too Verbose

**Reduce log level:**
```bash
# Edit config
sudo nano /etc/netopt/netopt.conf
# Set: LOG_LEVEL=WARN

# Or environment variable
sudo NETOPT_LOG_LEVEL=WARN systemctl restart netopt
```

### Missing Details in Logs

**Increase log level:**
```bash
# Edit config for DEBUG level
sudo nano /etc/netopt/netopt.conf
# Set: LOG_LEVEL=DEBUG

# Restart service
sudo systemctl restart netopt
```

### Service Not Logging to Journal

**Check StandardOutput setting:**
```bash
systemctl cat netopt.service | grep StandardOutput
# Should show: StandardOutput=journal
```

**Reload if needed:**
```bash
sudo systemctl daemon-reload
sudo systemctl restart netopt
```

---

## Log Rotation

### Automatic Rotation

Logs are automatically rotated when they exceed 10MB (configurable):

```bash
# In /etc/netopt/netopt.conf
NETOPT_LOG_MAX_SIZE=10485760  # 10MB in bytes
NETOPT_LOG_RETAIN_COUNT=5     # Keep 5 rotated files
```

### Manual Rotation

```bash
# Force log rotation
source /opt/netopt/lib/core/logger.sh
rotate_logs /var/log/netopt/netopt.log
```

### Rotation Behavior

```
netopt.log       (current, 9.8MB)
netopt.log.1     (previous, 10MB, compressed)
netopt.log.2     (older, 10MB, compressed)
netopt.log.3     (older, 10MB, compressed)
netopt.log.4     (older, 10MB, compressed)
netopt.log.5     (oldest, 10MB, compressed)
```

---

## Monitoring Integration

### Prometheus Metrics

Export metrics from logs:

```bash
# Parse latency metrics
grep "latency_ms" /var/log/netopt/netopt.json | \
    jq -r '.latency_ms' | \
    awk '{sum+=$1; count++} END {print "avg_latency_ms", sum/count}'

# Count optimizations
grep "event_type.*optimization" /var/log/netopt/netopt.json | wc -l

# Count failures
grep "event_result.*fail" /var/log/netopt/netopt.json | wc -l
```

### Grafana Dashboard Queries

Sample queries for visualization:

```sql
-- Average latency over time
SELECT
  time,
  avg(latency_ms) as avg_latency
FROM netopt_logs
WHERE timestamp > now() - interval '24 hours'
GROUP BY time(1h)

-- Interface health
SELECT
  interface,
  sum(case when status='alive' then 1 else 0 end) / count(*) * 100 as uptime_pct
FROM netopt_logs
GROUP BY interface
```

---

## Best Practices

### Production Logging

1. **Use INFO level** for production services
2. **Enable JSON logging** for monitoring integration
3. **Set up log rotation** to prevent disk fill
4. **Monitor log file sizes** regularly
5. **Archive old logs** to backup storage

### Development Logging

1. **Use DEBUG level** for troubleshooting
2. **Review pre-flight checks** for configuration issues
3. **Check validation phase** for connectivity problems
4. **Compare BEFORE/AFTER** states to verify changes
5. **Use journalctl filters** to focus on specific issues

### Performance Logging

1. **Log timing metrics** (`log_timing`) for performance tracking
2. **Record optimization duration** for trending
3. **Monitor memory/CPU usage** via resource limits
4. **Track cache hit rates** in performance logs

---

## Example Log Analysis Workflows

### Find Recent Failures
```bash
journalctl -u netopt --since today | grep ERROR
```

### Analyze Interface Performance
```bash
grep "Interface metrics" /var/log/netopt/netopt.json | \
    jq -r '[.interface, .latency_ms, .weight] | @csv'
```

### Check Optimization Frequency
```bash
journalctl -u netopt --since "7 days ago" | \
    grep "Service Starting" | wc -l
```

### Validate All Checks Passing
```bash
journalctl -u netopt -n 1 --output=cat | \
    grep "All pre-flight checks passed"
```

---

## Summary

NETOPT provides enterprise-grade logging with:

✅ **Detailed installer feedback** - Progress bars, change tracking, reports
✅ **Comprehensive service logging** - 5-phase execution with validation
✅ **Structured logging** - 5 levels, color-coded, with rotation
✅ **JSON logging** - For monitoring systems and analysis
✅ **Audit trail** - Complete record of all changes
✅ **Performance metrics** - Timing and resource usage tracking
✅ **Before/After comparisons** - Verify changes applied correctly
✅ **Integration ready** - Works with systemd journal, Prometheus, Grafana

All logs are production-ready with proper rotation, retention, and security considerations.
