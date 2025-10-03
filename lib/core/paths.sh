#!/bin/bash
# Smart path detection and management for NETOPT
# Automatically determines correct paths based on execution context

# Detect if running from installed location or development directory
detect_netopt_root() {
    local script_path="${BASH_SOURCE[0]}"
    local script_dir

    # Resolve symlinks to find actual location
    while [ -L "$script_path" ]; do
        script_dir="$(cd -P "$(dirname "$script_path")" && pwd)"
        script_path="$(readlink "$script_path")"
        [[ $script_path != /* ]] && script_path="$script_dir/$script_path"
    done

    script_dir="$(cd -P "$(dirname "$script_path")" && pwd)"

    # Navigate up from lib/core to root
    echo "$(cd "$script_dir/../.." && pwd)"
}

# Initialize NETOPT paths
init_paths() {
    # Detect root directory
    export NETOPT_ROOT="${NETOPT_ROOT:-$(detect_netopt_root)}"

    # Library paths
    export NETOPT_LIB_DIR="$NETOPT_ROOT/lib"
    export NETOPT_CORE_LIB="$NETOPT_LIB_DIR/core"
    export NETOPT_NETWORK_LIB="$NETOPT_LIB_DIR/network"
    export NETOPT_SYSTEM_LIB="$NETOPT_LIB_DIR/system"

    # Configuration paths
    export NETOPT_CONFIG_DIR="$NETOPT_ROOT/config"
    export NETOPT_PROFILES_DIR="$NETOPT_CONFIG_DIR/profiles"

    # Runtime paths - use /var/lib for system installation, local for dev
    if [ -w "/var/lib" ] && [ -d "/var/lib/netopt" -o "$NETOPT_INSTALL_MODE" = "system" ]; then
        export NETOPT_VAR_DIR="/var/lib/netopt"
        export NETOPT_LOG_DIR="/var/log/netopt"
    else
        export NETOPT_VAR_DIR="$NETOPT_ROOT/var"
        export NETOPT_LOG_DIR="$NETOPT_ROOT/log"
    fi

    # State and backup files
    export NETOPT_BACKUP_FILE="$NETOPT_VAR_DIR/route-backup.conf"
    export NETOPT_STATE_FILE="$NETOPT_VAR_DIR/current-state.conf"
    export NETOPT_LOCK_FILE="$NETOPT_VAR_DIR/netopt.lock"

    # Log files
    export NETOPT_LOG_FILE="$NETOPT_LOG_DIR/netopt.log"
    export NETOPT_ERROR_LOG="$NETOPT_LOG_DIR/error.log"
    export NETOPT_DEBUG_LOG="$NETOPT_LOG_DIR/debug.log"

    # Create necessary directories
    mkdir -p "$NETOPT_VAR_DIR" "$NETOPT_LOG_DIR" 2>/dev/null || true
}

# Verify all required paths exist
verify_paths() {
    local missing_paths=()

    # Check critical directories
    for dir in "$NETOPT_LIB_DIR" "$NETOPT_CONFIG_DIR"; do
        if [ ! -d "$dir" ]; then
            missing_paths+=("$dir")
        fi
    done

    if [ ${#missing_paths[@]} -gt 0 ]; then
        echo "ERROR: Missing required directories:" >&2
        printf '  %s\n' "${missing_paths[@]}" >&2
        return 1
    fi

    return 0
}

# Get path to a library module
get_lib_path() {
    local module="$1"

    case "$module" in
        core/*)
            echo "$NETOPT_CORE_LIB/${module#core/}"
            ;;
        network/*)
            echo "$NETOPT_NETWORK_LIB/${module#network/}"
            ;;
        system/*)
            echo "$NETOPT_SYSTEM_LIB/${module#system/}"
            ;;
        *)
            echo "$NETOPT_LIB_DIR/$module"
            ;;
    esac
}

# Source a library module safely
source_lib() {
    local module="$1"
    local lib_path="$(get_lib_path "$module")"

    if [ ! -f "$lib_path" ]; then
        echo "ERROR: Library module not found: $module ($lib_path)" >&2
        return 1
    fi

    # shellcheck source=/dev/null
    source "$lib_path"
}

# Get configuration file path
get_config_path() {
    local config="${1:-netopt.conf}"

    # Try user config first, then system config
    local user_config="$HOME/.config/netopt/$config"
    local system_config="$NETOPT_CONFIG_DIR/$config"

    if [ -f "$user_config" ]; then
        echo "$user_config"
    elif [ -f "$system_config" ]; then
        echo "$system_config"
    else
        # Return system config path even if it doesn't exist
        # (caller can create it)
        echo "$system_config"
    fi
}

# Initialize paths when this module is sourced
init_paths
