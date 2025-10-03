#!/bin/bash
################################################################################
# NETOPT Enhanced Installer Feedback System
# Provides detailed progress tracking, change reports, and validation
################################################################################

set -euo pipefail

# Progress tracking
TOTAL_STEPS=0
CURRENT_STEP=0
CHANGES_MADE=()
FILES_CREATED=()
FILES_MODIFIED=()
SERVICES_INSTALLED=()
DEPENDENCIES_INSTALLED=()

# Color codes
readonly C_HEADER='\033[1;34m'
readonly C_SUCCESS='\033[0;32m'
readonly C_WARNING='\033[1;33m'
readonly C_ERROR='\033[0;31m'
readonly C_INFO='\033[0;36m'
readonly C_BOLD='\033[1m'
readonly C_DIM='\033[2m'
readonly C_RESET='\033[0m'

################################################################################
# Progress Display
################################################################################

init_progress() {
    local total=${1:-10}
    TOTAL_STEPS=$total
    CURRENT_STEP=0
}

step_start() {
    local step_name="$*"
    CURRENT_STEP=$((CURRENT_STEP + 1))

    echo -e "${C_INFO}[${CURRENT_STEP}/${TOTAL_STEPS}]${C_RESET} ${C_BOLD}${step_name}...${C_RESET}"
}

step_complete() {
    echo -e "${C_SUCCESS}  ✓ Complete${C_RESET}"
    echo ""
}

step_skip() {
    local reason="$*"
    echo -e "${C_WARNING}  ⊘ Skipped${C_RESET}${C_DIM} (${reason})${C_RESET}"
    echo ""
}

step_fail() {
    local reason="$*"
    echo -e "${C_ERROR}  ✗ Failed${C_RESET}: $reason"
    echo ""
}

show_progress_bar() {
    local current=$1
    local total=$2
    local width=50

    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))

    printf "\r${C_INFO}Progress: [${C_RESET}"
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "${C_INFO}] ${percent}%%${C_RESET}"
}

################################################################################
# Change Tracking
################################################################################

track_change() {
    local change_type="$1"
    local change_description="$2"

    CHANGES_MADE+=("${change_type}|${change_description}")
}

track_file_created() {
    local file_path="$1"
    local file_type="${2:-file}"

    FILES_CREATED+=("${file_path}|${file_type}")
    track_change "CREATE" "$file_type: $file_path"
}

track_file_modified() {
    local file_path="$1"
    local modification="${2:-updated}"

    FILES_MODIFIED+=("${file_path}|${modification}")
    track_change "MODIFY" "$modification: $file_path"
}

track_service_installed() {
    local service_name="$1"
    local service_type="${2:-systemd}"

    SERVICES_INSTALLED+=("${service_name}|${service_type}")
    track_change "SERVICE" "Installed $service_type service: $service_name"
}

track_dependency_installed() {
    local package_name="$1"
    local package_manager="${2:-apt}"

    DEPENDENCIES_INSTALLED+=("${package_name}|${package_manager}")
    track_change "PACKAGE" "Installed via $package_manager: $package_name"
}

################################################################################
# Installation Report Generation
################################################################################

generate_installation_report() {
    local report_file="${1:-/tmp/netopt-install-report.txt}"

    cat > "$report_file" <<EOF
================================================================================
NETOPT INSTALLATION REPORT
================================================================================
Date: $(date '+%Y-%m-%d %H:%M:%S')
Hostname: $(hostname)
User: $USER (UID: $UID)
Installation Mode: ${INSTALL_MODE:-unknown}

================================================================================
PATHS CONFIGURED
================================================================================
Installation Directory: ${INSTALL_DIR:-N/A}
Configuration Directory: ${CONFIG_DIR:-N/A}
Binary Directory: ${BIN_DIR:-N/A}
Service Directory: ${SERVICE_DIR:-N/A}
Log Directory: ${INSTALL_DIR:-N/A}/logs
Checkpoint Directory: ${INSTALL_DIR:-N/A}/checkpoints

================================================================================
FILES CREATED (${#FILES_CREATED[@]} total)
================================================================================
EOF

    for entry in "${FILES_CREATED[@]}"; do
        IFS='|' read -r path type <<< "$entry"
        printf "  %-60s [%s]\n" "$path" "$type" >> "$report_file"
    done

    cat >> "$report_file" <<EOF

================================================================================
FILES MODIFIED (${#FILES_MODIFIED[@]} total)
================================================================================
EOF

    for entry in "${FILES_MODIFIED[@]}"; do
        IFS='|' read -r path mod <<< "$entry"
        printf "  %-60s (%s)\n" "$path" "$mod" >> "$report_file"
    done

    cat >> "$report_file" <<EOF

================================================================================
SERVICES INSTALLED (${#SERVICES_INSTALLED[@]} total)
================================================================================
EOF

    for entry in "${SERVICES_INSTALLED[@]}"; do
        IFS='|' read -r service type <<< "$entry"
        printf "  %-40s [%s]\n" "$service" "$type" >> "$report_file"
    done

    cat >> "$report_file" <<EOF

================================================================================
DEPENDENCIES INSTALLED (${#DEPENDENCIES_INSTALLED[@]} total)
================================================================================
EOF

    for entry in "${DEPENDENCIES_INSTALLED[@]}"; do
        IFS='|' read -r package manager <<< "$entry"
        printf "  %-40s (via %s)\n" "$package" "$manager" >> "$report_file"
    done

    cat >> "$report_file" <<EOF

================================================================================
SYSTEM CHANGES SUMMARY
================================================================================
Total Changes: ${#CHANGES_MADE[@]}
  - Files Created: ${#FILES_CREATED[@]}
  - Files Modified: ${#FILES_MODIFIED[@]}
  - Services Installed: ${#SERVICES_INSTALLED[@]}
  - Dependencies Installed: ${#DEPENDENCIES_INSTALLED[@]}

================================================================================
NEXT STEPS
================================================================================
1. Review configuration: ${CONFIG_DIR}/netopt.conf
2. Test installation: netopt --status
3. Apply optimizations: netopt --apply (or systemctl start netopt)
4. View logs: journalctl -u netopt -f (or ${INSTALL_DIR}/logs/netopt.log)
5. Create checkpoint: netopt --checkpoint
6. Documentation: ${INSTALL_DIR}/docs/

================================================================================
VERIFICATION COMMANDS
================================================================================
# Check installation
ls -la ${INSTALL_DIR}
ls -la ${CONFIG_DIR}

# Verify service
systemctl status netopt.service
# OR (user mode)
systemctl --user status netopt.service

# Test network optimization
sudo netopt --apply --dry-run

# View current configuration
cat ${CONFIG_DIR}/netopt.conf

================================================================================
SUPPORT
================================================================================
Documentation: ${INSTALL_DIR}/docs/
Issues: https://github.com/user/netopt/issues
Configuration Guide: ${INSTALL_DIR}/docs/CONFIGURATION.md

Report saved to: $report_file
================================================================================
EOF

    echo "$report_file"
}

show_installation_report() {
    echo ""
    echo -e "${C_HEADER}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_HEADER}║               NETOPT INSTALLATION SUMMARY                         ║${C_RESET}"
    echo -e "${C_HEADER}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""

    echo -e "${C_BOLD}Changes Applied:${C_RESET}"
    echo -e "  ${C_SUCCESS}✓${C_RESET} Files Created: ${#FILES_CREATED[@]}"
    echo -e "  ${C_SUCCESS}✓${C_RESET} Files Modified: ${#FILES_MODIFIED[@]}"
    echo -e "  ${C_SUCCESS}✓${C_RESET} Services Installed: ${#SERVICES_INSTALLED[@]}"
    echo -e "  ${C_SUCCESS}✓${C_RESET} Dependencies Installed: ${#DEPENDENCIES_INSTALLED[@]}"
    echo ""

    echo -e "${C_BOLD}Installation Details:${C_RESET}"
    echo -e "  Mode: ${C_INFO}${INSTALL_MODE}${C_RESET}"
    echo -e "  Location: ${C_INFO}${INSTALL_DIR}${C_RESET}"
    echo -e "  Config: ${C_INFO}${CONFIG_DIR}/netopt.conf${C_RESET}"
    echo ""

    if [[ ${#SERVICES_INSTALLED[@]} -gt 0 ]]; then
        echo -e "${C_BOLD}Services Available:${C_RESET}"
        for entry in "${SERVICES_INSTALLED[@]}"; do
            IFS='|' read -r service type <<< "$entry"
            echo -e "  ${C_SUCCESS}●${C_RESET} $service"
        done
        echo ""
    fi

    # Generate detailed report
    local report_file=$(generate_installation_report)
    echo -e "${C_INFO}Detailed report saved to: ${report_file}${C_RESET}"
    echo ""
}

################################################################################
# Before/After Comparison
################################################################################

capture_system_state() {
    local state_file="${1:-/tmp/netopt-state-before.txt}"

    cat > "$state_file" <<EOF
NETOPT System State Snapshot
Generated: $(date '+%Y-%m-%d %H:%M:%S')

=== Network Interfaces ===
$(ip -br link show)

=== IP Addresses ===
$(ip -br addr show)

=== Default Routes ===
$(ip route show default 2>/dev/null || echo "None")

=== Routing Rules ===
$(ip rule show 2>/dev/null | head -10)

=== DNS Configuration ===
$(cat /etc/resolv.conf 2>/dev/null || echo "Not accessible")

=== Network Services ===
$(systemctl list-units --type=service --state=running | grep -i "network\|netopt" || echo "None")

=== TCP Parameters ===
net.ipv4.tcp_congestion_control = $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
net.ipv4.tcp_fastopen = $(sysctl -n net.ipv4.tcp_fastopen 2>/dev/null || echo "unknown")
net.core.rmem_max = $(sysctl -n net.core.rmem_max 2>/dev/null || echo "unknown")
net.core.wmem_max = $(sysctl -n net.core.wmem_max 2>/dev/null || echo "unknown")

=== Disk Space ===
$(df -h / /var /home 2>/dev/null | head -4)
EOF

    echo "$state_file"
}

show_before_after_comparison() {
    local before_file="$1"
    local after_file="$2"

    echo ""
    echo -e "${C_HEADER}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_HEADER}║                 BEFORE / AFTER COMPARISON                         ║${C_RESET}"
    echo -e "${C_HEADER}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""

    # Compare default routes
    echo -e "${C_BOLD}Default Routes:${C_RESET}"
    echo -e "${C_DIM}BEFORE:${C_RESET}"
    grep -A2 "Default Routes" "$before_file" | tail -1 | sed 's/^/  /'
    echo -e "${C_DIM}AFTER:${C_RESET}"
    grep -A2 "Default Routes" "$after_file" | tail -1 | sed 's/^/  /'
    echo ""

    # Compare TCP settings
    echo -e "${C_BOLD}TCP Congestion Control:${C_RESET}"
    echo -e "${C_DIM}BEFORE:${C_RESET} $(grep "tcp_congestion_control" "$before_file" | awk -F'= ' '{print $2}')"
    echo -e "${C_DIM}AFTER:${C_RESET}  $(grep "tcp_congestion_control" "$after_file" | awk -F'= ' '{print $2}')"
    echo ""
}

################################################################################
# Interactive Confirmation with Details
################################################################################

confirm_changes() {
    local action="$1"
    shift
    local details=("$@")

    echo ""
    echo -e "${C_WARNING}The following changes will be made:${C_RESET}"
    echo ""

    for detail in "${details[@]}"; do
        echo -e "  ${C_INFO}●${C_RESET} $detail"
    done

    echo ""
    read -p "Proceed with $action? [y/N] " -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${C_WARNING}Operation cancelled by user${C_RESET}"
        return 1
    fi

    return 0
}

################################################################################
# Detailed File Operations with Feedback
################################################################################

install_file_with_feedback() {
    local source="$1"
    local dest="$2"
    local description="${3:-file}"

    if [[ ! -f "$source" ]]; then
        echo -e "  ${C_ERROR}✗${C_RESET} Source not found: $source"
        return 1
    fi

    local dest_dir="$(dirname "$dest")"
    if [[ ! -d "$dest_dir" ]]; then
        mkdir -p "$dest_dir" 2>/dev/null || sudo mkdir -p "$dest_dir"
        echo -e "  ${C_INFO}+${C_RESET} Created directory: $dest_dir"
    fi

    # Check if file exists (modification vs creation)
    if [[ -f "$dest" ]]; then
        local backup="${dest}.backup-$(date +%Y%m%d-%H%M%S)"
        cp "$dest" "$backup"
        echo -e "  ${C_WARNING}↻${C_RESET} Backed up existing: $(basename "$dest") → $(basename "$backup")"
        track_file_modified "$dest" "backed up to $backup"
    fi

    # Copy file
    cp "$source" "$dest" || sudo cp "$source" "$dest"
    chmod +x "$dest" 2>/dev/null || sudo chmod +x "$dest" 2>/dev/null || true

    local size=$(du -h "$dest" | cut -f1)
    echo -e "  ${C_SUCCESS}✓${C_RESET} Installed: $description ($size)"

    track_file_created "$dest" "$description"
}

install_directory_with_feedback() {
    local source_dir="$1"
    local dest_dir="$2"
    local description="${3:-directory}"

    if [[ ! -d "$source_dir" ]]; then
        echo -e "  ${C_ERROR}✗${C_RESET} Source directory not found: $source_dir"
        return 1
    fi

    mkdir -p "$dest_dir" 2>/dev/null || sudo mkdir -p "$dest_dir"

    local file_count=$(find "$source_dir" -type f | wc -l)
    local total_size=$(du -sh "$source_dir" | cut -f1)

    echo -e "  ${C_INFO}⟳${C_RESET} Copying $description: $file_count files, $total_size"

    cp -r "$source_dir"/* "$dest_dir/" 2>/dev/null || sudo cp -r "$source_dir"/* "$dest_dir/"

    echo -e "  ${C_SUCCESS}✓${C_RESET} Installed $description to: $dest_dir"

    track_file_created "$dest_dir" "$description"
}

################################################################################
# Dependency Installation with Detailed Feedback
################################################################################

install_package_with_feedback() {
    local package="$1"
    local pkg_manager="$2"

    echo -e "  ${C_INFO}⟳${C_RESET} Installing $package via $pkg_manager..."

    case "$pkg_manager" in
        apt)
            if sudo apt-get install -y "$package" 2>&1 | grep -q "is already the newest version"; then
                echo -e "  ${C_SUCCESS}✓${C_RESET} $package (already installed)"
            else
                echo -e "  ${C_SUCCESS}✓${C_RESET} $package installed"
                track_dependency_installed "$package" "apt"
            fi
            ;;
        dnf|yum)
            if sudo "$pkg_manager" install -y "$package" 2>&1 | grep -q "Nothing to do"; then
                echo -e "  ${C_SUCCESS}✓${C_RESET} $package (already installed)"
            else
                echo -e "  ${C_SUCCESS}✓${C_RESET} $package installed"
                track_dependency_installed "$package" "$pkg_manager"
            fi
            ;;
        pacman)
            if sudo pacman -S --noconfirm "$package" 2>&1 | grep -q "is up to date"; then
                echo -e "  ${C_SUCCESS}✓${C_RESET} $package (already installed)"
            else
                echo -e "  ${C_SUCCESS}✓${C_RESET} $package installed"
                track_dependency_installed "$package" "pacman"
            fi
            ;;
    esac
}

################################################################################
# Service Status Verification
################################################################################

verify_service_installation() {
    local service_name="$1"
    local service_type="${2:-system}"  # system or user

    echo ""
    echo -e "${C_BOLD}Verifying Service Installation:${C_RESET} $service_name"

    local systemctl_cmd="systemctl"
    [[ "$service_type" == "user" ]] && systemctl_cmd="systemctl --user"

    # Check if service file exists
    if $systemctl_cmd list-unit-files "$service_name" >/dev/null 2>&1; then
        echo -e "  ${C_SUCCESS}✓${C_RESET} Service file installed"
    else
        echo -e "  ${C_ERROR}✗${C_RESET} Service file NOT found"
        return 1
    fi

    # Check if service is enabled
    if $systemctl_cmd is-enabled "$service_name" >/dev/null 2>&1; then
        echo -e "  ${C_SUCCESS}✓${C_RESET} Service enabled (will start on boot)"
    else
        echo -e "  ${C_WARNING}⚠${C_RESET} Service not enabled"
    fi

    # Show service status
    echo -e "  ${C_INFO}Status:${C_RESET}"
    $systemctl_cmd status "$service_name" --no-pager -l 2>&1 | head -10 | sed 's/^/    /'

    return 0
}

################################################################################
# Final Installation Summary
################################################################################

show_final_summary() {
    echo ""
    echo -e "${C_HEADER}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_HEADER}║                  INSTALLATION COMPLETE                            ║${C_RESET}"
    echo -e "${C_HEADER}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""

    # Show statistics
    echo -e "${C_BOLD}Installation Statistics:${C_RESET}"
    echo -e "  Total Changes: ${C_SUCCESS}${#CHANGES_MADE[@]}${C_RESET}"
    echo -e "    • Files Created: ${#FILES_CREATED[@]}"
    echo -e "    • Files Modified: ${#FILES_MODIFIED[@]}"
    echo -e "    • Services Installed: ${#SERVICES_INSTALLED[@]}"
    echo -e "    • Dependencies Installed: ${#DEPENDENCIES_INSTALLED[@]}"
    echo ""

    # Show key locations
    echo -e "${C_BOLD}Key Locations:${C_RESET}"
    echo -e "  ${C_INFO}Command:${C_RESET}       netopt (${BIN_DIR}/netopt)"
    echo -e "  ${C_INFO}Install:${C_RESET}       ${INSTALL_DIR}"
    echo -e "  ${C_INFO}Config:${C_RESET}        ${CONFIG_DIR}/netopt.conf"
    echo -e "  ${C_INFO}Logs:${C_RESET}          ${INSTALL_DIR}/logs/"
    echo -e "  ${C_INFO}Checkpoints:${C_RESET}   ${INSTALL_DIR}/checkpoints/"
    echo ""

    # Show quick start commands
    echo -e "${C_BOLD}Quick Start Commands:${C_RESET}"

    if [[ "$INSTALL_MODE" == "$MODE_ROOT" ]]; then
        echo -e "  ${C_INFO}•${C_RESET} Apply now:          ${C_DIM}sudo systemctl start netopt${C_RESET}"
        echo -e "  ${C_INFO}•${C_RESET} Check status:       ${C_DIM}systemctl status netopt${C_RESET}"
        echo -e "  ${C_INFO}•${C_RESET} View logs:          ${C_DIM}journalctl -u netopt -f${C_RESET}"
    elif [[ "$INSTALL_MODE" == "$MODE_SYSTEMD_USER" ]]; then
        echo -e "  ${C_INFO}•${C_RESET} Apply now:          ${C_DIM}systemctl --user start netopt${C_RESET}"
        echo -e "  ${C_INFO}•${C_RESET} Check status:       ${C_DIM}systemctl --user status netopt${C_RESET}"
        echo -e "  ${C_INFO}•${C_RESET} View logs:          ${C_DIM}journalctl --user -u netopt -f${C_RESET}"
    else
        echo -e "  ${C_INFO}•${C_RESET} Apply now:          ${C_DIM}netopt --apply${C_RESET}"
        echo -e "  ${C_INFO}•${C_RESET} Check status:       ${C_DIM}netopt --status${C_RESET}"
        echo -e "  ${C_INFO}•${C_RESET} View logs:          ${C_DIM}cat ${INSTALL_DIR}/logs/netopt.log${C_RESET}"
    fi

    echo -e "  ${C_INFO}•${C_RESET} Restore settings:   ${C_DIM}netopt --restore${C_RESET}"
    echo -e "  ${C_INFO}•${C_RESET} Create checkpoint:  ${C_DIM}netopt --checkpoint${C_RESET}"
    echo ""

    # Generate and offer to display report
    local report_file=$(generate_installation_report)
    echo -e "${C_BOLD}Detailed Report:${C_RESET} ${report_file}"
    echo ""
    read -p "Display detailed installation report? [y/N] " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        cat "$report_file"
    fi
}

################################################################################
# Export functions
################################################################################

export -f init_progress step_start step_complete step_skip step_fail show_progress_bar
export -f track_change track_file_created track_file_modified track_service_installed track_dependency_installed
export -f generate_installation_report show_installation_report
export -f capture_system_state show_before_after_comparison
export -f confirm_changes install_file_with_feedback install_directory_with_feedback
export -f install_package_with_feedback verify_service_installation show_final_summary
