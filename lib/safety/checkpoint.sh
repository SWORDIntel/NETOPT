#!/bin/bash
################################################################################
# NETOPT Checkpoint System - Full State Snapshots & Recovery
# Creates complete system state backups for safe rollback
################################################################################

set -euo pipefail

# Source configuration if available
if [[ -f /etc/netopt/netopt.conf ]]; then
    source /etc/netopt/netopt.conf
elif [[ -f "$HOME/.config/netopt/netopt.conf" ]]; then
    source "$HOME/.config/netopt/netopt.conf"
fi

# Default checkpoint directory
CHECKPOINT_DIR="${CHECKPOINT_DIR:-$HOME/.netopt/checkpoints}"
CHECKPOINT_RETENTION="${CHECKPOINT_RETENTION:-10}"

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

################################################################################
# Logging
################################################################################

log_info() {
    echo -e "${BLUE}[CHECKPOINT]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[CHECKPOINT]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[CHECKPOINT]${NC} $*"
}

log_error() {
    echo -e "${RED}[CHECKPOINT]${NC} $*"
}

################################################################################
# State Capture Functions
################################################################################

capture_network_state() {
    local checkpoint_dir="$1"

    log_info "Capturing network interface state..."

    # Network interfaces
    ip addr show > "$checkpoint_dir/ip-addr.txt"
    ip route show > "$checkpoint_dir/ip-route.txt"
    ip link show > "$checkpoint_dir/ip-link.txt"

    # Interface statistics
    for iface in /sys/class/net/*; do
        if [[ -d "$iface" ]]; then
            local iface_name=$(basename "$iface")
            ethtool -k "$iface_name" > "$checkpoint_dir/ethtool-$iface_name.txt" 2>/dev/null || true
            ethtool -g "$iface_name" > "$checkpoint_dir/ethtool-ring-$iface_name.txt" 2>/dev/null || true
            ethtool -c "$iface_name" > "$checkpoint_dir/ethtool-coalesce-$iface_name.txt" 2>/dev/null || true
        fi
    done

    # Traffic control
    tc qdisc show > "$checkpoint_dir/tc-qdisc.txt"
    tc class show > "$checkpoint_dir/tc-class.txt" 2>/dev/null || true
    tc filter show > "$checkpoint_dir/tc-filter.txt" 2>/dev/null || true

    log_success "Network state captured"
}

capture_sysctl_state() {
    local checkpoint_dir="$1"

    log_info "Capturing sysctl parameters..."

    # All sysctl values
    sysctl -a > "$checkpoint_dir/sysctl-all.txt" 2>/dev/null || true

    # Network-specific sysctls
    sysctl -a | grep -E '^net\.' > "$checkpoint_dir/sysctl-net.txt" 2>/dev/null || true

    # Kernel-specific sysctls
    sysctl -a | grep -E '^kernel\.' > "$checkpoint_dir/sysctl-kernel.txt" 2>/dev/null || true

    # VM-specific sysctls
    sysctl -a | grep -E '^vm\.' > "$checkpoint_dir/sysctl-vm.txt" 2>/dev/null || true

    log_success "Sysctl state captured"
}

capture_module_state() {
    local checkpoint_dir="$1"

    log_info "Capturing kernel module state..."

    # Loaded modules
    lsmod > "$checkpoint_dir/lsmod.txt"

    # Module parameters
    for mod in /sys/module/*; do
        if [[ -d "$mod/parameters" ]]; then
            local mod_name=$(basename "$mod")
            mkdir -p "$checkpoint_dir/modules/$mod_name"

            for param in "$mod/parameters/"*; do
                if [[ -f "$param" ]]; then
                    local param_name=$(basename "$param")
                    cat "$param" > "$checkpoint_dir/modules/$mod_name/$param_name" 2>/dev/null || true
                fi
            done
        fi
    done

    log_success "Module state captured"
}

capture_service_state() {
    local checkpoint_dir="$1"

    log_info "Capturing service state..."

    # Systemd services
    systemctl list-units --type=service --all > "$checkpoint_dir/systemctl-services.txt" 2>/dev/null || true

    # Network-related services
    systemctl status networking > "$checkpoint_dir/service-networking.txt" 2>/dev/null || true
    systemctl status NetworkManager > "$checkpoint_dir/service-networkmanager.txt" 2>/dev/null || true
    systemctl status systemd-networkd > "$checkpoint_dir/service-systemd-networkd.txt" 2>/dev/null || true

    log_success "Service state captured"
}

capture_performance_state() {
    local checkpoint_dir="$1"

    log_info "Capturing performance metrics..."

    # CPU info
    cat /proc/cpuinfo > "$checkpoint_dir/cpuinfo.txt"

    # Memory info
    cat /proc/meminfo > "$checkpoint_dir/meminfo.txt"

    # Load average
    cat /proc/loadavg > "$checkpoint_dir/loadavg.txt"

    # Network statistics
    cat /proc/net/dev > "$checkpoint_dir/net-dev.txt"
    cat /proc/net/sockstat > "$checkpoint_dir/net-sockstat.txt"
    cat /proc/net/netstat > "$checkpoint_dir/net-netstat.txt"
    cat /proc/net/snmp > "$checkpoint_dir/net-snmp.txt"

    # Interrupt statistics
    cat /proc/interrupts > "$checkpoint_dir/interrupts.txt"

    log_success "Performance metrics captured"
}

capture_firewall_state() {
    local checkpoint_dir="$1"

    log_info "Capturing firewall state..."

    # iptables
    if command -v iptables-save >/dev/null 2>&1; then
        sudo iptables-save > "$checkpoint_dir/iptables.txt" 2>/dev/null || true
    fi

    # nftables
    if command -v nft >/dev/null 2>&1; then
        sudo nft list ruleset > "$checkpoint_dir/nftables.txt" 2>/dev/null || true
    fi

    # firewalld
    if command -v firewall-cmd >/dev/null 2>&1; then
        sudo firewall-cmd --list-all > "$checkpoint_dir/firewalld.txt" 2>/dev/null || true
    fi

    log_success "Firewall state captured"
}

################################################################################
# Checkpoint Creation
################################################################################

create_checkpoint() {
    local checkpoint_name="${1:-auto}"
    local description="${2:-Automatic checkpoint}"

    # Generate checkpoint ID
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local checkpoint_id="${checkpoint_name}_${timestamp}"
    local checkpoint_path="$CHECKPOINT_DIR/$checkpoint_id"

    log_info "Creating checkpoint: $checkpoint_id"

    # Create checkpoint directory
    mkdir -p "$checkpoint_path"

    # Create metadata
    cat > "$checkpoint_path/metadata.json" <<EOF
{
    "id": "$checkpoint_id",
    "name": "$checkpoint_name",
    "description": "$description",
    "timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "kernel": "$(uname -r)",
    "user": "$USER",
    "uid": "$UID"
}
EOF

    # Capture all state components
    capture_network_state "$checkpoint_path"
    capture_sysctl_state "$checkpoint_path"
    capture_module_state "$checkpoint_path"
    capture_service_state "$checkpoint_path"
    capture_performance_state "$checkpoint_path"
    capture_firewall_state "$checkpoint_path"

    # Create compressed archive
    log_info "Compressing checkpoint..."
    tar -czf "$checkpoint_path.tar.gz" -C "$CHECKPOINT_DIR" "$checkpoint_id"

    # Remove uncompressed directory
    rm -rf "$checkpoint_path"

    log_success "Checkpoint created: $checkpoint_path.tar.gz"

    # Cleanup old checkpoints
    cleanup_old_checkpoints

    echo "$checkpoint_id"
}

################################################################################
# Checkpoint Restoration
################################################################################

restore_checkpoint() {
    local checkpoint_id="$1"
    local checkpoint_path="$CHECKPOINT_DIR/${checkpoint_id}.tar.gz"

    if [[ ! -f "$checkpoint_path" ]]; then
        log_error "Checkpoint not found: $checkpoint_id"
        return 1
    fi

    log_warning "Restoring checkpoint: $checkpoint_id"

    # Extract checkpoint with validated temp directory
    local temp_dir
    temp_dir=$(mktemp -d) || {
        log_error "Failed to create temporary directory"
        return 1
    }

    # Validate temp directory path for safety
    if [[ -z "$temp_dir" ]] || [[ ! "$temp_dir" =~ ^/tmp/ ]]; then
        log_error "Invalid temporary directory: $temp_dir"
        return 1
    fi

    # Setup cleanup trap
    trap 'rm -rf "$temp_dir"' EXIT INT TERM

    tar -xzf "$checkpoint_path" -C "$temp_dir"
    local extracted_dir="$temp_dir/$checkpoint_id"

    # Verify checkpoint integrity
    if [[ ! -f "$extracted_dir/metadata.json" ]]; then
        log_error "Invalid checkpoint: missing metadata"
        rm -rf "$temp_dir"
        trap - EXIT INT TERM
        return 1
    fi

    # Display checkpoint information
    log_info "Checkpoint details:"
    cat "$extracted_dir/metadata.json"
    echo ""

    read -p "Continue with restoration? [y/N] " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Restoration cancelled"
        rm -rf "$temp_dir"
        return 0
    fi

    # Create backup of current state
    log_info "Creating backup of current state..."
    create_checkpoint "pre_restore" "Backup before restoring $checkpoint_id"

    # Restore sysctl parameters
    if [[ -f "$extracted_dir/sysctl-net.txt" ]]; then
        log_info "Restoring sysctl parameters..."
        while IFS='=' read -r key value; do
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            sudo sysctl -w "$key=$value" 2>/dev/null || true
        done < "$extracted_dir/sysctl-net.txt"
        log_success "Sysctl parameters restored"
    fi

    # Restore traffic control (reset to defaults)
    if [[ -f "$extracted_dir/tc-qdisc.txt" ]]; then
        log_info "Resetting traffic control..."
        for iface in $(ip -o link show | awk -F': ' '{print $2}'); do
            sudo tc qdisc del dev "$iface" root 2>/dev/null || true
        done
        log_success "Traffic control reset"
    fi

    # Restore interface features
    if ls "$extracted_dir"/ethtool-*.txt >/dev/null 2>&1; then
        log_info "Restoring interface features..."
        for ethtool_file in "$extracted_dir"/ethtool-*.txt; do
            local iface=$(basename "$ethtool_file" | sed 's/ethtool-\(.*\)\.txt/\1/')
            # Parse and restore ethtool settings
            # This is complex and may require custom parsing
            log_info "Interface $iface settings logged (manual review recommended)"
        done
    fi

    # Cleanup
    rm -rf "$temp_dir"

    log_success "Checkpoint restoration complete"
    log_warning "Please review system state and reboot if necessary"
}

################################################################################
# Checkpoint Management
################################################################################

list_checkpoints() {
    log_info "Available checkpoints:"
    echo ""

    if [[ ! -d "$CHECKPOINT_DIR" ]]; then
        log_warning "No checkpoints found"
        return 0
    fi

    local count=0
    for checkpoint in "$CHECKPOINT_DIR"/*.tar.gz; do
        if [[ -f "$checkpoint" ]]; then
            local checkpoint_name=$(basename "$checkpoint" .tar.gz)
            local size=$(du -h "$checkpoint" | cut -f1)
            local date=$(stat -c %y "$checkpoint" | cut -d' ' -f1,2 | cut -d'.' -f1)

            echo "ID: $checkpoint_name"
            echo "  Size: $size"
            echo "  Date: $date"
            echo ""

            count=$((count + 1))
        fi
    done

    if [[ $count -eq 0 ]]; then
        log_warning "No checkpoints found"
    else
        log_info "Total checkpoints: $count"
    fi
}

delete_checkpoint() {
    local checkpoint_id="$1"
    local checkpoint_path="$CHECKPOINT_DIR/${checkpoint_id}.tar.gz"

    if [[ ! -f "$checkpoint_path" ]]; then
        log_error "Checkpoint not found: $checkpoint_id"
        return 1
    fi

    log_warning "Deleting checkpoint: $checkpoint_id"
    rm -f "$checkpoint_path"
    log_success "Checkpoint deleted"
}

cleanup_old_checkpoints() {
    log_info "Cleaning up old checkpoints (retention: $CHECKPOINT_RETENTION)..."

    local checkpoint_count=$(find "$CHECKPOINT_DIR" -name "*.tar.gz" | wc -l)

    if [[ $checkpoint_count -le $CHECKPOINT_RETENTION ]]; then
        log_info "No cleanup needed ($checkpoint_count <= $CHECKPOINT_RETENTION)"
        return 0
    fi

    # Delete oldest checkpoints
    local delete_count=$((checkpoint_count - CHECKPOINT_RETENTION))
    find "$CHECKPOINT_DIR" -name "*.tar.gz" -type f -printf '%T+ %p\n' | \
        sort | head -n "$delete_count" | cut -d' ' -f2- | \
        while read -r checkpoint; do
            log_info "Removing old checkpoint: $(basename "$checkpoint")"
            rm -f "$checkpoint"
        done

    log_success "Cleanup complete"
}

compare_checkpoints() {
    local checkpoint1="$1"
    local checkpoint2="$2"

    log_info "Comparing checkpoints: $checkpoint1 vs $checkpoint2"

    local temp_dir=$(mktemp -d)
    tar -xzf "$CHECKPOINT_DIR/${checkpoint1}.tar.gz" -C "$temp_dir"
    tar -xzf "$CHECKPOINT_DIR/${checkpoint2}.tar.gz" -C "$temp_dir"

    # Compare sysctl parameters
    log_info "Sysctl differences:"
    diff -u "$temp_dir/$checkpoint1/sysctl-net.txt" "$temp_dir/$checkpoint2/sysctl-net.txt" || true

    # Cleanup
    rm -rf "$temp_dir"
}

################################################################################
# CLI Interface
################################################################################

show_usage() {
    cat <<EOF
NETOPT Checkpoint System

Usage: $0 <command> [options]

Commands:
    create <name> [description]   Create a new checkpoint
    restore <id>                  Restore a checkpoint
    list                          List all checkpoints
    delete <id>                   Delete a checkpoint
    compare <id1> <id2>           Compare two checkpoints
    cleanup                       Remove old checkpoints

Examples:
    $0 create baseline "Initial system state"
    $0 restore baseline_20250101_120000
    $0 list
    $0 delete old_checkpoint_20241201_000000

EOF
}

main() {
    # Ensure checkpoint directory exists
    mkdir -p "$CHECKPOINT_DIR"

    local command="${1:-}"

    case "$command" in
        create)
            create_checkpoint "${2:-auto}" "${3:-Manual checkpoint}"
            ;;
        restore)
            if [[ -z "${2:-}" ]]; then
                log_error "Checkpoint ID required"
                show_usage
                exit 1
            fi
            restore_checkpoint "$2"
            ;;
        list)
            list_checkpoints
            ;;
        delete)
            if [[ -z "${2:-}" ]]; then
                log_error "Checkpoint ID required"
                show_usage
                exit 1
            fi
            delete_checkpoint "$2"
            ;;
        compare)
            if [[ -z "${2:-}" ]] || [[ -z "${3:-}" ]]; then
                log_error "Two checkpoint IDs required"
                show_usage
                exit 1
            fi
            compare_checkpoints "$2" "$3"
            ;;
        cleanup)
            cleanup_old_checkpoints
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

# Allow sourcing for library usage
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
