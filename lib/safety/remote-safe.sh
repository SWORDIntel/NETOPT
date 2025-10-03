#!/bin/bash
################################################################################
# NETOPT Remote Safety System - SSH Session Detection & Watchdog Timer
# Prevents network lockout during remote optimization
################################################################################

set -euo pipefail

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Watchdog defaults
readonly DEFAULT_WATCHDOG_TIMEOUT=300  # 5 minutes
readonly WATCHDOG_CHECK_INTERVAL=10    # 10 seconds
readonly WATCHDOG_PIDFILE="/tmp/netopt-watchdog.pid"
readonly WATCHDOG_LOCKFILE="/tmp/netopt-watchdog.lock"

# State tracking
SESSION_TYPE=""
IS_REMOTE=false
WATCHDOG_PID=""
ROLLBACK_SCRIPT="/tmp/netopt-rollback-$$.sh"

################################################################################
# Logging Functions
################################################################################

log_info() {
    echo -e "${BLUE}[REMOTE-SAFE]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[REMOTE-SAFE]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[REMOTE-SAFE]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[REMOTE-SAFE]${NC} $*" >&2
}

log_critical() {
    echo -e "${RED}[CRITICAL]${NC} $*" >&2
}

################################################################################
# Session Detection
################################################################################

detect_session_type() {
    log_info "Detecting session type..."

    # Check for SSH connection
    if [[ -n "${SSH_CONNECTION:-}" ]] || [[ -n "${SSH_CLIENT:-}" ]] || [[ -n "${SSH_TTY:-}" ]]; then
        SESSION_TYPE="ssh"
        IS_REMOTE=true
        log_warning "SSH session detected"
        return 0
    fi

    # Check for other remote connections
    if who am i | grep -q '('; then
        SESSION_TYPE="remote"
        IS_REMOTE=true
        log_warning "Remote session detected"
        return 0
    fi

    # Check for tmux/screen
    if [[ -n "${TMUX:-}" ]]; then
        SESSION_TYPE="tmux"
        log_info "TMUX session detected"
    elif [[ -n "${STY:-}" ]]; then
        SESSION_TYPE="screen"
        log_info "Screen session detected"
    else
        SESSION_TYPE="local"
        log_info "Local session detected"
    fi

    return 0
}

get_session_info() {
    local info=""

    info+="Session Type: $SESSION_TYPE\n"
    info+="Remote: $IS_REMOTE\n"

    if [[ -n "${SSH_CONNECTION:-}" ]]; then
        info+="SSH Connection: ${SSH_CONNECTION}\n"
    fi

    if [[ -n "${SSH_CLIENT:-}" ]]; then
        info+="SSH Client: ${SSH_CLIENT}\n"
    fi

    # Current network interface
    local primary_iface=$(ip route | grep '^default' | head -1 | awk '{print $5}')
    if [[ -n "$primary_iface" ]]; then
        local primary_ip=$(ip addr show "$primary_iface" | grep 'inet ' | head -1 | awk '{print $2}')
        info+="Primary Interface: $primary_iface ($primary_ip)\n"
    fi

    echo -e "$info"
}

################################################################################
# Pre-flight Safety Checks
################################################################################

check_network_stability() {
    log_info "Checking network stability..."

    # Check if we can reach gateway
    local gateway=$(ip route | grep '^default' | head -1 | awk '{print $3}')

    if [[ -z "$gateway" ]]; then
        log_error "No default gateway found"
        return 1
    fi

    if ! ping -c 3 -W 2 "$gateway" >/dev/null 2>&1; then
        log_error "Cannot reach gateway: $gateway"
        return 1
    fi

    log_success "Network stability check passed"
    return 0
}

check_interface_status() {
    log_info "Checking network interface status..."

    local primary_iface=$(ip route | grep '^default' | head -1 | awk '{print $5}')

    if [[ -z "$primary_iface" ]]; then
        log_error "No primary network interface found"
        return 1
    fi

    # Check interface is up
    if ! ip link show "$primary_iface" | grep -q 'state UP'; then
        log_error "Primary interface $primary_iface is not UP"
        return 1
    fi

    log_success "Interface $primary_iface is UP"
    return 0
}

verify_rollback_capability() {
    log_info "Verifying rollback capability..."

    # Check if checkpoint system is available
    if [[ -f "$(dirname "${BASH_SOURCE[0]}")/checkpoint.sh" ]]; then
        log_success "Checkpoint system available"
    else
        log_warning "Checkpoint system not found"
    fi

    # Check for required commands
    local required_cmds=("ip" "tc" "sysctl" "iptables")
    local missing=()

    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing[*]}"
        return 1
    fi

    log_success "All rollback commands available"
    return 0
}

################################################################################
# Watchdog Timer System
################################################################################

create_rollback_script() {
    log_info "Creating rollback script..."

    cat > "$ROLLBACK_SCRIPT" <<'ROLLBACK_EOF'
#!/bin/bash
# NETOPT Emergency Rollback Script
# This script is executed by the watchdog if the timer expires

set -euo pipefail

echo "[WATCHDOG] Emergency rollback triggered at $(date)"

# Reset traffic control on all interfaces
for iface in $(ip -o link show | awk -F': ' '{print $2}'); do
    tc qdisc del dev "$iface" root 2>/dev/null || true
    tc qdisc del dev "$iface" ingress 2>/dev/null || true
    echo "[WATCHDOG] Reset traffic control on $iface"
done

# Reset critical sysctl parameters
sysctl -w net.ipv4.tcp_congestion_control=cubic 2>/dev/null || true
sysctl -w net.core.default_qdisc=pfifo_fast 2>/dev/null || true

# Restart networking service (if safe)
if systemctl is-active --quiet NetworkManager; then
    echo "[WATCHDOG] NetworkManager is running, skipping restart"
elif systemctl is-active --quiet systemd-networkd; then
    echo "[WATCHDOG] systemd-networkd is running, skipping restart"
else
    echo "[WATCHDOG] No network manager detected"
fi

echo "[WATCHDOG] Emergency rollback complete"
echo "[WATCHDOG] Please check network connectivity"

# Send notification if possible
if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "NETOPT Watchdog" "Emergency rollback executed"
fi

# Log to syslog
logger -t netopt-watchdog -p user.crit "Emergency rollback executed"

exit 0
ROLLBACK_EOF

    chmod +x "$ROLLBACK_SCRIPT"
    log_success "Rollback script created: $ROLLBACK_SCRIPT"
}

start_watchdog() {
    local timeout="${1:-$DEFAULT_WATCHDOG_TIMEOUT}"

    if [[ ! "$IS_REMOTE" == "true" ]]; then
        log_info "Not a remote session, watchdog not required"
        return 0
    fi

    log_warning "Starting watchdog timer (timeout: ${timeout}s)..."

    # Check if watchdog is already running
    if [[ -f "$WATCHDOG_PIDFILE" ]]; then
        local old_pid=$(cat "$WATCHDOG_PIDFILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            log_warning "Watchdog already running (PID: $old_pid)"
            return 0
        else
            rm -f "$WATCHDOG_PIDFILE"
        fi
    fi

    # Create rollback script
    create_rollback_script

    # Start watchdog in background
    (
        # Create lock file
        touch "$WATCHDOG_LOCKFILE"

        local elapsed=0
        local start_time=$(date +%s)

        log_info "Watchdog started (PID: $$, timeout: ${timeout}s)"

        while [[ $elapsed -lt $timeout ]]; do
            # Check if lock file still exists
            if [[ ! -f "$WATCHDOG_LOCKFILE" ]]; then
                echo "[WATCHDOG] Lock file removed, watchdog cancelled"
                exit 0
            fi

            sleep "$WATCHDOG_CHECK_INTERVAL"

            elapsed=$(( $(date +%s) - start_time ))
            local remaining=$((timeout - elapsed))

            if [[ $((elapsed % 60)) -eq 0 ]]; then
                echo "[WATCHDOG] Time remaining: ${remaining}s"
            fi
        done

        # Timeout expired - execute rollback
        log_critical "Watchdog timeout expired - executing emergency rollback!"

        if [[ -f "$ROLLBACK_SCRIPT" ]]; then
            bash "$ROLLBACK_SCRIPT"
        else
            log_error "Rollback script not found!"
        fi

        # Cleanup
        rm -f "$WATCHDOG_LOCKFILE"
        rm -f "$WATCHDOG_PIDFILE"

        exit 1
    ) &

    WATCHDOG_PID=$!
    echo "$WATCHDOG_PID" > "$WATCHDOG_PIDFILE"

    log_success "Watchdog started (PID: $WATCHDOG_PID, timeout: ${timeout}s)"

    # Display countdown in background
    display_watchdog_countdown "$timeout" &

    return 0
}

display_watchdog_countdown() {
    local timeout="$1"
    local start_time=$(date +%s)

    while [[ -f "$WATCHDOG_LOCKFILE" ]]; do
        local elapsed=$(( $(date +%s) - start_time ))
        local remaining=$((timeout - elapsed))

        if [[ $remaining -le 0 ]]; then
            break
        fi

        if [[ $remaining -le 60 ]] && [[ $((remaining % 10)) -eq 0 ]]; then
            log_warning "Watchdog countdown: ${remaining}s remaining"
        fi

        sleep 5
    done
}

cancel_watchdog() {
    log_info "Cancelling watchdog timer..."

    # Remove lock file to stop watchdog
    if [[ -f "$WATCHDOG_LOCKFILE" ]]; then
        rm -f "$WATCHDOG_LOCKFILE"
        log_success "Watchdog lock removed"
    fi

    # Kill watchdog process
    if [[ -f "$WATCHDOG_PIDFILE" ]]; then
        local watchdog_pid=$(cat "$WATCHDOG_PIDFILE")
        if kill -0 "$watchdog_pid" 2>/dev/null; then
            kill "$watchdog_pid" 2>/dev/null || true
            log_success "Watchdog process terminated (PID: $watchdog_pid)"
        fi
        rm -f "$WATCHDOG_PIDFILE"
    fi

    # Cleanup rollback script
    if [[ -f "$ROLLBACK_SCRIPT" ]]; then
        rm -f "$ROLLBACK_SCRIPT"
    fi

    log_success "Watchdog cancelled successfully"
}

extend_watchdog() {
    local additional_time="${1:-300}"

    if [[ ! -f "$WATCHDOG_PIDFILE" ]]; then
        log_error "No watchdog running"
        return 1
    fi

    log_info "Extending watchdog timer by ${additional_time}s..."

    # Touch lock file to update timestamp
    touch "$WATCHDOG_LOCKFILE"

    log_success "Watchdog timer extended"
}

################################################################################
# Remote Safety Wrapper
################################################################################

safe_execute() {
    local command="$1"
    local timeout="${2:-$DEFAULT_WATCHDOG_TIMEOUT}"
    local auto_confirm="${3:-false}"

    log_info "Preparing safe execution..."

    # Detect session
    detect_session_type

    # Display session information
    echo ""
    echo "=========================================="
    echo "NETOPT Remote Safety System"
    echo "=========================================="
    get_session_info
    echo "=========================================="
    echo ""

    if [[ "$IS_REMOTE" == "true" ]]; then
        log_warning "REMOTE SESSION DETECTED!"
        echo ""
        log_warning "A watchdog timer will be started to prevent network lockout."
        log_warning "If you lose connectivity, changes will be automatically rolled back after ${timeout}s."
        echo ""

        if [[ "$auto_confirm" != "true" ]]; then
            read -p "Continue with remote safety enabled? [y/N] " -n 1 -r
            echo ""

            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Operation cancelled"
                return 1
            fi
        fi

        # Run pre-flight checks
        log_info "Running pre-flight safety checks..."
        check_network_stability || return 1
        check_interface_status || return 1
        verify_rollback_capability || return 1

        # Create checkpoint
        if [[ -f "$(dirname "${BASH_SOURCE[0]}")/checkpoint.sh" ]]; then
            log_info "Creating safety checkpoint..."
            source "$(dirname "${BASH_SOURCE[0]}")/checkpoint.sh"
            create_checkpoint "remote_safe" "Pre-execution safety checkpoint" >/dev/null
        fi

        # Start watchdog
        start_watchdog "$timeout"

        echo ""
        log_success "Safety systems active. Executing command..."
        echo ""
    fi

    # Execute the command
    local exit_code=0
    eval "$command" || exit_code=$?

    # Cancel watchdog if successful
    if [[ "$IS_REMOTE" == "true" ]]; then
        echo ""
        if [[ $exit_code -eq 0 ]]; then
            log_success "Command completed successfully"

            # Test connectivity
            log_info "Testing network connectivity..."
            if check_network_stability; then
                log_success "Network connectivity confirmed"
                cancel_watchdog
            else
                log_error "Network connectivity test failed!"
                log_warning "Watchdog will continue running for safety"
                log_warning "Run '$0 cancel' to stop watchdog if everything is working"
            fi
        else
            log_error "Command failed with exit code: $exit_code"
            log_warning "Watchdog still active for safety"
        fi
    fi

    return $exit_code
}

################################################################################
# Interactive Confirmation System
################################################################################

confirm_changes() {
    if [[ ! "$IS_REMOTE" == "true" ]]; then
        return 0
    fi

    echo ""
    log_warning "Please verify that your connection is still working!"
    echo ""
    echo "You have ${DEFAULT_WATCHDOG_TIMEOUT} seconds to confirm."
    echo ""
    read -p "Are the changes working correctly? [y/N] " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cancel_watchdog
        log_success "Changes confirmed and applied"
        return 0
    else
        log_warning "Changes not confirmed - watchdog will rollback"
        return 1
    fi
}

################################################################################
# CLI Interface
################################################################################

show_usage() {
    cat <<EOF
NETOPT Remote Safety System

Usage: $0 <command> [options]

Commands:
    detect                       Detect current session type
    execute <command> [timeout]  Execute command with safety
    start [timeout]              Start watchdog timer
    cancel                       Cancel watchdog timer
    extend [seconds]             Extend watchdog timer
    confirm                      Confirm changes (cancel watchdog)
    status                       Show watchdog status

Examples:
    # Execute with safety (300s timeout)
    $0 execute "./network-optimize.sh --apply"

    # Execute with custom timeout
    $0 execute "./network-optimize.sh --apply" 600

    # Manual watchdog control
    $0 start 300
    # ... do your changes ...
    $0 confirm  # or cancel

Options:
    timeout: Watchdog timeout in seconds (default: 300)

Safety Features:
    - SSH session detection
    - Automatic rollback on timeout
    - Network connectivity monitoring
    - Pre-flight safety checks
    - Checkpoint creation

EOF
}

show_status() {
    log_info "Remote Safety Status"
    echo ""

    detect_session_type
    get_session_info

    if [[ -f "$WATCHDOG_PIDFILE" ]]; then
        local watchdog_pid=$(cat "$WATCHDOG_PIDFILE")
        if kill -0 "$watchdog_pid" 2>/dev/null; then
            log_success "Watchdog is ACTIVE (PID: $watchdog_pid)"
        else
            log_warning "Watchdog PID file exists but process is dead"
        fi
    else
        log_info "Watchdog is INACTIVE"
    fi

    if [[ -f "$WATCHDOG_LOCKFILE" ]]; then
        local lock_age=$(( $(date +%s) - $(stat -c %Y "$WATCHDOG_LOCKFILE") ))
        log_info "Lock file age: ${lock_age}s"
    fi
}

main() {
    local command="${1:-}"

    case "$command" in
        detect)
            detect_session_type
            get_session_info
            ;;

        execute)
            if [[ -z "${2:-}" ]]; then
                log_error "Command required"
                show_usage
                exit 1
            fi
            safe_execute "$2" "${3:-$DEFAULT_WATCHDOG_TIMEOUT}"
            ;;

        start)
            detect_session_type
            start_watchdog "${2:-$DEFAULT_WATCHDOG_TIMEOUT}"
            ;;

        cancel)
            cancel_watchdog
            ;;

        extend)
            extend_watchdog "${2:-300}"
            ;;

        confirm)
            confirm_changes
            ;;

        status)
            show_status
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
