#!/bin/bash
# Structured logging facility for NETOPT
# Provides multiple log levels, rotation, and flexible output formatting

# Log levels
declare -gA LOG_LEVELS=(
    [DEBUG]=0
    [INFO]=1
    [WARN]=2
    [ERROR]=3
    [FATAL]=4
)

# ANSI color codes
declare -gA LOG_COLORS=(
    [DEBUG]='\033[0;36m'    # Cyan
    [INFO]='\033[0;32m'     # Green
    [WARN]='\033[0;33m'     # Yellow
    [ERROR]='\033[0;31m'    # Red
    [FATAL]='\033[1;31m'    # Bold Red
    [RESET]='\033[0m'       # Reset
)

# Current log level (default to INFO)
CURRENT_LOG_LEVEL="${CURRENT_LOG_LEVEL:-INFO}"

# Initialize logger
init_logger() {
    local log_file="${1:-${NETOPT_LOG_FILE:-/var/log/netopt/netopt.log}}"
    local log_level="${2:-${NETOPT_LOG_LEVEL:-INFO}}"

    export NETOPT_LOG_FILE="$log_file"
    export CURRENT_LOG_LEVEL="$log_level"

    # Create log directory if it doesn't exist
    local log_dir="$(dirname "$log_file")"
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir" 2>/dev/null || {
            echo "WARNING: Cannot create log directory: $log_dir" >&2
            export NETOPT_LOG_FILE="/dev/null"
            return 1
        }
    fi

    # Test log file writability
    if ! touch "$log_file" 2>/dev/null; then
        echo "WARNING: Cannot write to log file: $log_file" >&2
        export NETOPT_LOG_FILE="/dev/null"
        return 1
    fi

    return 0
}

# Check if a log level should be logged
should_log() {
    local level="$1"
    local current_level_num="${LOG_LEVELS[$CURRENT_LOG_LEVEL]:-1}"
    local message_level_num="${LOG_LEVELS[$level]:-0}"

    [ "$message_level_num" -ge "$current_level_num" ]
}

# Format log message with timestamp and level
format_log_message() {
    local level="$1"
    local message="$2"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    printf "[%s] %-5s: %s" "$timestamp" "$level" "$message"
}

# Write to log file
write_to_log() {
    local message="$1"
    local log_file="${NETOPT_LOG_FILE:-/dev/null}"

    if [ "$log_file" != "/dev/null" ]; then
        echo "$message" >> "$log_file" 2>/dev/null || true
    fi
}

# Main logging function
log_message() {
    local level="$1"
    shift
    local message="$*"

    # Check if we should log this level
    if ! should_log "$level"; then
        return 0
    fi

    # Format the message
    local formatted_message="$(format_log_message "$level" "$message")"

    # Write to log file
    write_to_log "$formatted_message"

    # Write to console with color if connected to a terminal
    if [ -t 1 ]; then
        local color="${LOG_COLORS[$level]:-${LOG_COLORS[RESET]}}"
        local reset="${LOG_COLORS[RESET]}"
        echo -e "${color}${formatted_message}${reset}"
    else
        echo "$formatted_message"
    fi
}

# Convenience functions for each log level
log_debug() {
    log_message "DEBUG" "$@"
}

log_info() {
    log_message "INFO" "$@"
}

log_warn() {
    log_message "WARN" "$@"
}

log_error() {
    log_message "ERROR" "$@"
}

log_fatal() {
    log_message "FATAL" "$@"
}

# Legacy compatibility - simple log function
log() {
    log_info "$@"
}

# Log with custom prefix (for subsystems)
log_subsystem() {
    local subsystem="$1"
    local level="$2"
    shift 2
    local message="$*"

    log_message "$level" "[$subsystem] $message"
}

# Log command execution with output capture
log_exec() {
    local level="${1:-INFO}"
    shift
    local command="$*"

    log_message "$level" "Executing: $command"

    local output
    local exit_code

    output="$($command 2>&1)"
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        if [ -n "$output" ]; then
            log_message "$level" "Output: $output"
        fi
    else
        log_message "ERROR" "Command failed (exit $exit_code): $command"
        if [ -n "$output" ]; then
            log_message "ERROR" "Output: $output"
        fi
    fi

    return $exit_code
}

# Rotate log files
rotate_logs() {
    local log_file="${NETOPT_LOG_FILE:-/var/log/netopt/netopt.log}"
    local max_size="${1:-${NETOPT_LOG_MAX_SIZE:-10485760}}"  # 10MB default
    local retain_count="${2:-${NETOPT_LOG_RETAIN_COUNT:-5}}"

    # Check if log file exists and is large enough to rotate
    if [ ! -f "$log_file" ]; then
        return 0
    fi

    local file_size
    file_size="$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0)"

    if [ "$file_size" -lt "$max_size" ]; then
        return 0
    fi

    log_info "Rotating log file: $log_file (size: $file_size bytes)"

    # Rotate existing backups
    local i
    for ((i=retain_count-1; i>=1; i--)); do
        local old_file="${log_file}.${i}"
        local new_file="${log_file}.$((i+1))"

        if [ -f "$old_file" ]; then
            mv "$old_file" "$new_file" 2>/dev/null || true
        fi
    done

    # Move current log to .1
    mv "$log_file" "${log_file}.1" 2>/dev/null || true

    # Create new empty log file
    touch "$log_file" 2>/dev/null || true

    # Delete old logs beyond retain count
    for ((i=retain_count+1; i<=retain_count+10; i++)); do
        local old_file="${log_file}.${i}"
        if [ -f "$old_file" ]; then
            rm -f "$old_file" 2>/dev/null || true
        fi
    done
}

# Log separator for visual clarity
log_separator() {
    local char="${1:-=}"
    local length="${2:-60}"
    local separator="$(printf "%${length}s" | tr ' ' "$char")"

    log_info "$separator"
}

# Log section header
log_section() {
    local title="$*"
    log_separator "="
    log_info "$title"
    log_separator "="
}
