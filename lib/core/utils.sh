#!/bin/bash
# Common utility functions for NETOPT
# Provides reusable helpers for various operations

# Check if running as root
is_root() {
    [ "$(id -u)" -eq 0 ]
}

# Require root privileges
require_root() {
    if ! is_root; then
        echo "ERROR: This operation requires root privileges" >&2
        echo "Please run with: sudo $0 $*" >&2
        exit 1
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Require a command to be installed
require_command() {
    local cmd="$1"
    local package="${2:-$1}"

    if ! command_exists "$cmd"; then
        echo "ERROR: Required command not found: $cmd" >&2
        echo "Please install: $package" >&2
        return 1
    fi

    return 0
}

# Check multiple required commands
require_commands() {
    local missing=()

    for cmd in "$@"; do
        if ! command_exists "$cmd"; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "ERROR: Required commands not found:" >&2
        printf '  %s\n' "${missing[@]}" >&2
        return 1
    fi

    return 0
}

# Safe command execution with error handling
safe_exec() {
    local cmd="$*"
    local output
    local exit_code

    output="$($cmd 2>&1)"
    exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo "ERROR: Command failed: $cmd" >&2
        if [ -n "$output" ]; then
            echo "Output: $output" >&2
        fi
        return $exit_code
    fi

    echo "$output"
    return 0
}

# Run command with retry logic
retry_command() {
    local max_attempts="${1:-3}"
    local delay="${2:-2}"
    shift 2
    local cmd="$*"

    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if $cmd; then
            return 0
        fi

        if [ $attempt -lt $max_attempts ]; then
            echo "Attempt $attempt failed, retrying in ${delay}s..." >&2
            sleep "$delay"
        fi

        ((attempt++))
    done

    echo "ERROR: Command failed after $max_attempts attempts: $cmd" >&2
    return 1
}

# Create directory with proper error handling
ensure_directory() {
    local dir="$1"
    local mode="${2:-0755}"

    if [ -d "$dir" ]; then
        return 0
    fi

    if ! mkdir -p "$dir" 2>/dev/null; then
        echo "ERROR: Cannot create directory: $dir" >&2
        return 1
    fi

    chmod "$mode" "$dir" 2>/dev/null || true
    return 0
}

# Create file with content atomically
atomic_write() {
    local file="$1"
    local content="$2"
    local temp_file="${file}.tmp.$$"

    # Write to temporary file
    if ! echo "$content" > "$temp_file" 2>/dev/null; then
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi

    # Atomic move
    if ! mv "$temp_file" "$file" 2>/dev/null; then
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi

    return 0
}

# Backup a file before modification
backup_file() {
    local file="$1"
    local backup_suffix="${2:-.bak}"

    if [ ! -f "$file" ]; then
        return 0
    fi

    local backup="${file}${backup_suffix}"

    if ! cp -p "$file" "$backup" 2>/dev/null; then
        echo "WARNING: Cannot create backup: $backup" >&2
        return 1
    fi

    return 0
}

# Lock file management (prevents concurrent execution)
acquire_lock() {
    local lock_file="${1:-${NETOPT_LOCK_FILE:-/var/run/netopt.lock}}"
    local timeout="${2:-30}"
    local wait_time=0

    # Ensure lock directory exists
    ensure_directory "$(dirname "$lock_file")" || return 1

    # Wait for lock to be available
    while [ -f "$lock_file" ] && [ $wait_time -lt $timeout ]; do
        # Check if lock is stale (process no longer exists)
        if [ -r "$lock_file" ]; then
            local lock_pid
            lock_pid="$(cat "$lock_file" 2>/dev/null)"
            if [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
                # Stale lock, remove it
                rm -f "$lock_file" 2>/dev/null
                break
            fi
        fi

        sleep 1
        ((wait_time++))
    done

    # Check if we timed out
    if [ -f "$lock_file" ]; then
        echo "ERROR: Cannot acquire lock (timeout after ${timeout}s): $lock_file" >&2
        return 1
    fi

    # Create lock file atomically with our PID (prevents race condition)
    (set -o noclobber; echo "$$" > "$lock_file") 2>/dev/null || {
        echo "ERROR: Cannot create lock file (already exists or no permission): $lock_file" >&2
        return 1
    }

    return 0
}

# Release lock file
release_lock() {
    local lock_file="${1:-${NETOPT_LOCK_FILE:-/var/run/netopt.lock}}"

    # Only remove if we own it
    if [ -f "$lock_file" ]; then
        local lock_pid
        lock_pid="$(cat "$lock_file" 2>/dev/null)"
        if [ "$lock_pid" = "$$" ]; then
            rm -f "$lock_file" 2>/dev/null
        fi
    fi
}

# Cleanup function to be called on exit
cleanup_on_exit() {
    release_lock
}

# Register cleanup handler
register_cleanup() {
    trap cleanup_on_exit EXIT INT TERM
}

# Validate IP address format
is_valid_ip() {
    local ip="$1"

    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        local IFS='.'
        local -a octets=($ip)

        for octet in "${octets[@]}"; do
            if [ "$octet" -gt 255 ]; then
                return 1
            fi
        done

        return 0
    fi

    return 1
}

# Validate network interface name
is_valid_interface() {
    local iface="$1"

    [ -d "/sys/class/net/$iface" ]
}

# Get interface state (up/down)
get_interface_state() {
    local iface="$1"

    if ! is_valid_interface "$iface"; then
        return 1
    fi

    if ip link show "$iface" 2>/dev/null | grep -q "state UP"; then
        echo "up"
        return 0
    else
        echo "down"
        return 1
    fi
}

# Convert bytes to human-readable format
bytes_to_human() {
    local bytes="$1"
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    local size="$bytes"

    while [ "$size" -ge 1024 ] && [ $unit -lt 4 ]; do
        size=$((size / 1024))
        ((unit++))
    done

    echo "${size}${units[$unit]}"
}

# Get system uptime in seconds
get_uptime() {
    local uptime_seconds
    uptime_seconds="$(cat /proc/uptime 2>/dev/null | awk '{print int($1)}')"
    echo "${uptime_seconds:-0}"
}

# Check if system has been recently booted (within last N seconds)
is_recent_boot() {
    local threshold="${1:-300}"  # 5 minutes default
    local uptime
    uptime="$(get_uptime)"

    [ "$uptime" -lt "$threshold" ]
}

# Parse yes/no user input
ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local response

    while true; do
        if [ "$default" = "y" ]; then
            read -r -p "$prompt [Y/n]: " response
            response="${response:-y}"
        else
            read -r -p "$prompt [y/N]: " response
            response="${response:-n}"
        fi

        case "${response,,}" in
            y|yes)
                return 0
                ;;
            n|no)
                return 1
                ;;
            *)
                echo "Please answer yes or no."
                ;;
        esac
    done
}

# Calculate percentage
calculate_percentage() {
    local value="$1"
    local total="$2"
    local decimals="${3:-0}"

    if [ "$total" -eq 0 ]; then
        echo "0"
        return
    fi

    local percentage
    percentage=$(awk -v val="$value" -v tot="$total" -v dec="$decimals" \
        'BEGIN { printf "%.*f", dec, (val/tot)*100 }')

    echo "$percentage"
}
