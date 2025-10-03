#!/bin/bash
# Configuration loading and management for NETOPT
# Handles default values, config file parsing, and environment overrides

# Default configuration values
declare -gA NETOPT_CONFIG=(
    # Connection type priorities (lower = higher priority)
    [PRIORITY_ETHERNET]=10
    [PRIORITY_WIFI]=20
    [PRIORITY_MOBILE]=30
    [PRIORITY_UNKNOWN]=40

    # Latency settings
    [MAX_LATENCY]=200
    [PING_COUNT]=3
    [PING_TIMEOUT]=1

    # Weight calculation
    [MIN_WEIGHT]=1
    [MAX_WEIGHT]=20
    [LATENCY_DIVISOR]=10

    # Priority multipliers
    [ETHERNET_MULTIPLIER]=2
    [WIFI_MULTIPLIER]=1
    [MOBILE_MULTIPLIER]=0.5

    # DNS servers
    [DNS_PRIMARY]="1.1.1.1"
    [DNS_SECONDARY]="1.0.0.1"
    [DNS_TERTIARY]="8.8.8.8"

    # TCP optimization settings
    [TCP_FASTOPEN]=3
    [TCP_CONGESTION]="bbr"
    [RMEM_MAX]=16777216
    [WMEM_MAX]=16777216
    [TCP_NO_METRICS_SAVE]=1

    # Interface filters (regex patterns to exclude)
    [EXCLUDE_INTERFACES]="^lo$|^docker|^veth|^br-|^virbr"

    # Logging
    [LOG_LEVEL]="INFO"
    [LOG_MAX_SIZE]=10485760
    [LOG_RETAIN_COUNT]=5

    # Behavior flags
    [AUTO_RESTORE_ON_FAILURE]=1
    [ENABLE_TCP_OPTIMIZATION]=1
    [ENABLE_DNS_CONFIGURATION]=1
    [USE_DNSMASQ_IF_AVAILABLE]=1
)

# Load configuration from file
load_config() {
    local config_file="${1:-}"

    if [ -z "$config_file" ]; then
        # Try to find config file using paths.sh
        if declare -f get_config_path >/dev/null 2>&1; then
            config_file="$(get_config_path netopt.conf)"
        else
            config_file="${NETOPT_CONFIG_DIR:-/etc/netopt}/netopt.conf"
        fi
    fi

    if [ ! -f "$config_file" ]; then
        return 0  # Not an error, will use defaults
    fi

    # Parse config file
    local line_num=0
    while IFS= read -r line || [ -n "$line" ]; do
        ((line_num++))

        # Skip comments and empty lines
        line="${line%%#*}"  # Remove comments
        line="${line#"${line%%[![:space:]]*}"}"  # Trim leading whitespace
        line="${line%"${line##*[![:space:]]}"}"  # Trim trailing whitespace

        [ -z "$line" ] && continue

        # Parse KEY=VALUE
        if [[ $line =~ ^([A-Z_][A-Z0-9_]*)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Remove quotes if present
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"

            NETOPT_CONFIG["$key"]="$value"
        else
            echo "WARNING: Invalid config syntax at line $line_num: $line" >&2
        fi
    done < "$config_file"

    return 0
}

# Get configuration value with fallback
get_config() {
    local key="$1"
    local default="${2:-}"

    # Check environment variable first (NETOPT_KEY)
    local env_var="NETOPT_${key}"
    if [ -n "${!env_var:-}" ]; then
        echo "${!env_var}"
        return 0
    fi

    # Check config array
    if [ -n "${NETOPT_CONFIG[$key]:-}" ]; then
        echo "${NETOPT_CONFIG[$key]}"
        return 0
    fi

    # Return default
    echo "$default"
    return 0
}

# Get integer config value
get_config_int() {
    local key="$1"
    local default="${2:-0}"
    local value

    value="$(get_config "$key" "$default")"

    # Validate integer
    if [[ $value =~ ^-?[0-9]+$ ]]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# Get boolean config value (1=true, 0=false)
get_config_bool() {
    local key="$1"
    local default="${2:-0}"
    local value

    value="$(get_config "$key" "$default")"

    case "${value,,}" in
        1|true|yes|on|enabled)
            echo "1"
            ;;
        0|false|no|off|disabled)
            echo "0"
            ;;
        *)
            echo "$default"
            ;;
    esac
}

# Set configuration value at runtime
set_config() {
    local key="$1"
    local value="$2"

    NETOPT_CONFIG["$key"]="$value"
}

# Export configuration as environment variables
export_config() {
    local prefix="${1:-NETOPT_}"

    for key in "${!NETOPT_CONFIG[@]}"; do
        export "${prefix}${key}=${NETOPT_CONFIG[$key]}"
    done
}

# Print current configuration (for debugging)
print_config() {
    local filter="${1:-.*}"

    echo "Current NETOPT Configuration:"
    echo "=============================="

    for key in $(printf '%s\n' "${!NETOPT_CONFIG[@]}" | sort); do
        if [[ $key =~ $filter ]]; then
            printf "%-30s = %s\n" "$key" "${NETOPT_CONFIG[$key]}"
        fi
    done
}

# Validate configuration
validate_config() {
    local errors=0

    # Validate priorities are positive integers
    for priority_key in PRIORITY_ETHERNET PRIORITY_WIFI PRIORITY_MOBILE PRIORITY_UNKNOWN; do
        local value="${NETOPT_CONFIG[$priority_key]}"
        if ! [[ $value =~ ^[0-9]+$ ]] || [ "$value" -lt 1 ]; then
            echo "ERROR: Invalid $priority_key: $value (must be positive integer)" >&2
            ((errors++))
        fi
    done

    # Validate latency settings
    local max_latency="${NETOPT_CONFIG[MAX_LATENCY]}"
    if ! [[ $max_latency =~ ^[0-9]+$ ]] || [ "$max_latency" -lt 1 ]; then
        echo "ERROR: Invalid MAX_LATENCY: $max_latency" >&2
        ((errors++))
    fi

    # Validate weights
    local min_weight="${NETOPT_CONFIG[MIN_WEIGHT]}"
    local max_weight="${NETOPT_CONFIG[MAX_WEIGHT]}"
    if [ "$min_weight" -ge "$max_weight" ]; then
        echo "ERROR: MIN_WEIGHT ($min_weight) must be less than MAX_WEIGHT ($max_weight)" >&2
        ((errors++))
    fi

    return $errors
}
