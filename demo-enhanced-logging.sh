#!/bin/bash
################################################################################
# NETOPT Enhanced Logging Demo
# Demonstrates installer feedback and service logging capabilities
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes
readonly C_HEADER='\033[1;34m'
readonly C_SUCCESS='\033[0;32m'
readonly C_INFO='\033[0;36m'
readonly C_BOLD='\033[1m'
readonly C_RESET='\033[0m'

show_demo_menu() {
    clear
    cat <<EOF
╔══════════════════════════════════════════════════════════════╗
║        NETOPT Enhanced Logging & Feedback Demo              ║
╚══════════════════════════════════════════════════════════════╝

Select a demo to run:

1. ${C_SUCCESS}Installer Progress Tracking Demo${C_RESET}
   - Shows step-by-step installation progress
   - Displays file creation tracking
   - Generates detailed change report

2. ${C_SUCCESS}Service Logging Demo${C_RESET}
   - Shows all 5 logging phases
   - Demonstrates structured logging
   - Shows before/after state comparison

3. ${C_SUCCESS}View Sample Installation Report${C_RESET}
   - Display example installation report
   - Shows all tracked changes

4. ${C_SUCCESS}View Sample Service Logs${C_RESET}
   - Display example service execution log
   - Shows validation and metrics

5. ${C_SUCCESS}Test Live Installer Feedback${C_RESET}
   - Run installer with enhanced feedback (dry-run)

6. ${C_INFO}View Documentation${C_RESET}
   - Open LOGGING-GUIDE.md

7. ${C_INFO}Exit${C_RESET}

EOF
    read -p "Select option [1-7]: " -n 1 -r choice
    echo ""
    return $choice
}

demo_installer_progress() {
    echo ""
    echo -e "${C_HEADER}╔══════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_HEADER}║           INSTALLER PROGRESS TRACKING DEMO                   ║${C_RESET}"
    echo -e "${C_HEADER}╚══════════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""

    # Source the feedback system
    source "$SCRIPT_DIR/lib/installer/installer-feedback.sh"

    # Simulate installation
    init_progress 8

    step_start "Detecting system privileges"
    sleep 1
    echo "  Detected: Running with sudo access"
    track_change "CONFIG" "Installation mode set to: root"
    step_complete

    step_start "Configuring installation paths"
    sleep 0.5
    INSTALL_DIR="/opt/netopt"
    CONFIG_DIR="/etc/netopt"
    BIN_DIR="/usr/local/bin"
    echo "  Install directory: $INSTALL_DIR"
    echo "  Config directory: $CONFIG_DIR"
    track_change "PATH" "Configured installation paths"
    step_complete

    step_start "Creating directories"
    sleep 0.5
    track_file_created "/opt/netopt" "directory"
    track_file_created "/etc/netopt" "directory"
    echo "  Created: /opt/netopt"
    echo "  Created: /etc/netopt"
    step_complete

    step_start "Installing library files"
    sleep 1
    track_file_created "/opt/netopt/lib/core/logger.sh" "library"
    track_file_created "/opt/netopt/lib/network/detection.sh" "library"
    track_file_created "/opt/netopt/lib/safety/checkpoint.sh" "library"
    echo "  Installed 3 library files (22 KB total)"
    step_complete

    step_start "Installing systemd service"
    sleep 0.5
    track_service_installed "netopt.service" "systemd"
    echo "  Service file: /etc/systemd/system/netopt.service"
    echo "  Service enabled for boot"
    step_complete

    step_start "Creating configuration file"
    sleep 0.5
    track_file_created "/etc/netopt/netopt.conf" "configuration"
    echo "  Configuration: /etc/netopt/netopt.conf"
    step_complete

    step_start "Installing dependencies"
    sleep 1
    track_dependency_installed "iproute2" "apt"
    track_dependency_installed "ethtool" "apt"
    echo "  Installed: iproute2, ethtool"
    step_complete

    step_start "Creating initial checkpoint"
    sleep 1
    track_change "CHECKPOINT" "Created initial system snapshot"
    echo "  Checkpoint: initial_20251003_143522"
    step_complete

    # Show summary
    echo ""
    show_installation_report

    echo ""
    read -p "Press Enter to continue..."
}

demo_service_logging() {
    echo ""
    echo -e "${C_HEADER}╔══════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_HEADER}║              SERVICE LOGGING DEMO                            ║${C_RESET}"
    echo -e "${C_HEADER}╚══════════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""

    # Source the service logger
    source "$SCRIPT_DIR/lib/network/service-logger.sh"

    # Simulate service execution
    log_service_start

    log_preflight_start
    log_preflight_check "Network Interfaces" "pass" "3 interfaces UP"
    log_preflight_check "Gateway Connectivity" "pass" "192.168.1.1 reachable"
    log_preflight_check "Required Commands" "pass" "ip, ping, sysctl found"
    log_preflight_check "Configuration File" "pass" "/etc/netopt/netopt.conf"
    log_preflight_complete 4 0

    echo ""
    log_network_state "BEFORE"

    echo ""
    log_optimization_phase "Network Optimization"

    log_interface_test "enp3s0" "ethernet" "192.168.1.1"
    sleep 0.5
    log_interface_test_result "enp3s0" "alive" "2" "40"

    log_interface_test "wlp2s0" "wifi" "192.168.1.1"
    sleep 0.5
    log_interface_test_result "wlp2s0" "alive" "15" "18"

    echo ""
    log_route_application 2 "enp3s0(ethernet:2ms:w40) wlp2s0(wifi:15ms:w18)"
    sleep 0.3
    log_route_success

    echo ""
    log_tcp_optimization "tcp_congestion_control" "bbr"
    log_tcp_optimization "tcp_fastopen" "3"
    log_tcp_optimization "rmem_max" "16777216"
    log_tcp_optimization "wmem_max" "16777216"
    log_tcp_optimization_complete

    echo ""
    start_time=$(($(date +%s) - 3))
    log_timing "Network optimization" "$start_time"

    echo ""
    log_validation_start
    sleep 1
    log_validation_result "Multipath Route" "true" "2 nexthops"
    log_validation_result "Gateway Connectivity" "true" "192.168.1.1 responds"
    log_validation_result "Internet Connectivity" "true" "8.8.8.8 reachable"
    log_validation_result "DNS Resolution" "true" "DNS working"

    echo ""
    log_network_state "AFTER"

    echo ""
    log_separator "="
    log_info "NETOPT Service Started Successfully"
    log_info "Active connections optimized and validated"
    log_separator "="

    # Show JSON log example
    echo ""
    echo -e "${C_BOLD}Sample JSON Log Entry:${C_RESET}"
    log_event_json "optimization" "apply_routes" "success" "interface_count=2" "total_weight=58"

    echo ""
    read -p "Press Enter to continue..."
}

view_sample_report() {
    echo ""
    cat <<'EOF'
================================================================================
NETOPT INSTALLATION REPORT (Sample)
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
  /opt/netopt/lib/core/utils.sh                              [library]
  /opt/netopt/lib/network/detection.sh                       [library]
  /opt/netopt/lib/network/testing-parallel.sh                [library]
  /opt/netopt/lib/network/cache.sh                           [library]
  /opt/netopt/lib/network/bgp-intelligence.sh                [library]
  /opt/netopt/lib/safety/checkpoint.sh                       [library]
  /etc/netopt/netopt.conf                                    [configuration]
  /etc/systemd/system/netopt.service                         [service]
  /usr/local/bin/netopt                                      [symlink]

================================================================================
FILES MODIFIED (2 total)
================================================================================
  /etc/resolv.conf                                           (DNS servers)
  ~/.bashrc                                                  (PATH updated)

================================================================================
SERVICES INSTALLED (1 total)
================================================================================
  netopt.service                                             [systemd]

================================================================================
DEPENDENCIES INSTALLED (2 total)
================================================================================
  ethtool                                                     (via apt)
  mtr-tiny                                                    (via apt)

================================================================================
SYSTEM CHANGES SUMMARY
================================================================================
Total Changes: 18
  - Files Created: 13
  - Files Modified: 2
  - Services Installed: 1
  - Dependencies Installed: 2

================================================================================
NEXT STEPS
================================================================================
1. Review configuration: /etc/netopt/netopt.conf
2. Test installation: netopt --status
3. Apply optimizations: sudo systemctl start netopt
4. View logs: journalctl -u netopt -f
5. Create checkpoint: netopt --checkpoint

Report saved to: /tmp/netopt-install-report-20251003-143022.txt
================================================================================
EOF

    echo ""
    read -p "Press Enter to continue..."
}

view_sample_service_logs() {
    echo ""
    cat <<'EOF'
================================================================================
NETOPT SERVICE EXECUTION LOG (Sample)
================================================================================

[2025-10-03 14:35:00] INFO: ============================================================
[2025-10-03 14:35:00] INFO: NETOPT Service Starting
[2025-10-03 14:35:00] INFO: ============================================================
[2025-10-03 14:35:00] INFO: Timestamp: 2025-10-03 14:35:00 UTC
[2025-10-03 14:35:00] INFO: Hostname: your-hostname
[2025-10-03 14:35:00] INFO: User: root
[2025-10-03 14:35:00] INFO: PID: 12345

--- PRE-FLIGHT CHECKS ---
[2025-10-03 14:35:01] INFO:   ✓ Network Interfaces (3 interfaces UP)
[2025-10-03 14:35:01] INFO:   ✓ Gateway Connectivity (192.168.1.1 reachable)
[2025-10-03 14:35:01] INFO:   ✓ Command: ip (/usr/sbin/ip)
[2025-10-03 14:35:01] INFO:   ✓ Command: ping (/usr/bin/ping)
[2025-10-03 14:35:01] INFO:   ✓ Configuration File (/etc/netopt/netopt.conf)
[2025-10-03 14:35:01] INFO: Pre-flight Summary: 4 passed, 0 failed

--- NETWORK STATE (BEFORE) ---
[2025-10-03 14:35:01] INFO:   Active Interfaces: 3
[2025-10-03 14:35:01] INFO:     enp3s0           UP             192.168.1.50/24
[2025-10-03 14:35:01] INFO:     wlp2s0           UP             192.168.1.51/24
[2025-10-03 14:35:01] INFO:   Default Routes:
[2025-10-03 14:35:01] INFO:     default via 192.168.1.1 dev enp3s0 metric 100

--- CHECKPOINT ---
[2025-10-03 14:35:02] INFO: Creating pre-optimization checkpoint...
[2025-10-03 14:35:02] INFO: ✓ Checkpoint created: service_20251003_143502
[2025-10-03 14:35:02] DEBUG:   Location: /opt/netopt/checkpoints/service_20251003_143502.tar.gz

--- OPTIMIZATION PHASE ---
[2025-10-03 14:35:03] INFO: Testing Interface: enp3s0 (ethernet) via 192.168.1.1
[2025-10-03 14:35:04] INFO:   ✓ ALIVE - Latency: 2ms, Weight: 40
[2025-10-03 14:35:04] INFO: Testing Interface: wlp2s0 (wifi) via 192.168.1.1
[2025-10-03 14:35:05] INFO:   ✓ ALIVE - Latency: 15ms, Weight: 18
[2025-10-03 14:35:05] INFO: Applying load-balanced route with 2 connection(s)
[2025-10-03 14:35:05] INFO:   Configuration: enp3s0(ethernet:2ms:w40) wlp2s0(wifi:15ms:w18)
[2025-10-03 14:35:05] INFO: ✓ Load balancing enabled successfully

--- TCP OPTIMIZATION ---
[2025-10-03 14:35:05] DEBUG: TCP Optimization: tcp_congestion_control = bbr
[2025-10-03 14:35:05] DEBUG: TCP Optimization: tcp_fastopen = 3
[2025-10-03 14:35:05] INFO: ✓ TCP optimizations applied

--- PERFORMANCE METRICS ---
[2025-10-03 14:35:06] INFO: ⏱ Network optimization completed in 3s
[2025-10-03 14:35:06] DEBUG: Performance: optimization_duration = 3s

--- POST-VALIDATION ---
[2025-10-03 14:35:09] INFO:   ✓ Multipath Route (2 nexthops)
[2025-10-03 14:35:11] INFO:   ✓ Gateway Connectivity (192.168.1.1 responds)
[2025-10-03 14:35:13] INFO:   ✓ Internet Connectivity (8.8.8.8 reachable)
[2025-10-03 14:35:14] INFO:   ✓ DNS Resolution (DNS working)

--- NETWORK STATE (AFTER) ---
[2025-10-03 14:35:14] INFO:   Default Routes:
[2025-10-03 14:35:14] INFO:     default proto static metric 1024
[2025-10-03 14:35:14] INFO:       nexthop via 192.168.1.1 dev enp3s0 weight 40
[2025-10-03 14:35:14] INFO:       nexthop via 192.168.1.1 dev wlp2s0 weight 18

[2025-10-03 14:35:14] INFO: ============================================================
[2025-10-03 14:35:14] INFO: NETOPT Service Started Successfully
[2025-10-03 14:35:14] INFO: ============================================================

--- JSON LOG ENTRIES ---
{"timestamp":"2025-10-03T14:35:14.123Z","level":"INFO","message":"service: start - success","service":"netopt","hostname":"your-hostname","pid":12345,"event_type":"service","event_action":"start","event_result":"success","phase":"complete"}

{"timestamp":"2025-10-03T14:35:04.456Z","level":"INFO","message":"Interface metrics","service":"netopt","hostname":"your-hostname","pid":12345,"interface":"enp3s0","type":"ethernet","gateway":"192.168.1.1","latency_ms":"2","weight":"40","status":"alive"}

================================================================================
EOF

    echo ""
    read -p "Press Enter to continue..."
}

test_live_installer() {
    echo ""
    echo -e "${C_INFO}Testing installer with enhanced feedback (simulated)...${C_RESET}"
    echo ""

    source "$SCRIPT_DIR/lib/installer/installer-feedback.sh"

    # Capture before state
    echo "Capturing system state..."
    local before_state=$(capture_system_state "/tmp/netopt-demo-before.txt")
    echo -e "${C_SUCCESS}✓ Before-state captured: $before_state${C_RESET}"

    # Simulate changes
    INSTALL_MODE="root"
    INSTALL_DIR="/opt/netopt"
    CONFIG_DIR="/etc/netopt"
    BIN_DIR="/usr/local/bin"
    SERVICE_DIR="/etc/systemd/system"

    track_file_created "/opt/netopt/netopt.sh" "main script"
    track_file_created "/etc/netopt/netopt.conf" "configuration"
    track_service_installed "netopt.service" "systemd"

    # Show report
    show_final_summary

    echo ""
    read -p "Press Enter to continue..."
}

view_documentation() {
    if [[ -f "$SCRIPT_DIR/docs/LOGGING-GUIDE.md" ]]; then
        less "$SCRIPT_DIR/docs/LOGGING-GUIDE.md"
    else
        echo "Documentation not found: $SCRIPT_DIR/docs/LOGGING-GUIDE.md"
        read -p "Press Enter to continue..."
    fi
}

################################################################################
# Main Demo Loop
################################################################################

main() {
    while true; do
        show_demo_menu
        choice=$?

        case $choice in
            1)
                demo_installer_progress
                ;;
            2)
                demo_service_logging
                ;;
            3)
                view_sample_report
                ;;
            4)
                view_sample_service_logs
                ;;
            5)
                test_live_installer
                ;;
            6)
                view_documentation
                ;;
            7)
                echo "Exiting demo..."
                exit 0
                ;;
            *)
                echo "Invalid choice"
                sleep 2
                ;;
        esac
    done
}

main "$@"
