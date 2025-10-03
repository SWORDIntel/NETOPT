#!/bin/bash
################################################################################
# NETOPT Smart Installer - Privilege Detection & Adaptive Installation
# Automatically detects execution context and adapts installation strategy
################################################################################

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Installation modes
readonly MODE_ROOT="root"
readonly MODE_SYSTEMD_USER="systemd-user"
readonly MODE_PORTABLE="portable"

# Global variables
INSTALL_MODE=""
INSTALL_DIR=""
CONFIG_DIR=""
SERVICE_DIR=""
BIN_DIR=""

################################################################################
# Logging Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

################################################################################
# Privilege Detection
################################################################################

detect_privileges() {
    log_info "Detecting execution context..."

    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_info "Detected: Running as root"
        INSTALL_MODE="$MODE_ROOT"
        return 0
    fi

    # Check if user has sudo access
    if sudo -n true 2>/dev/null; then
        log_info "Detected: User has passwordless sudo access"
        INSTALL_MODE="$MODE_ROOT"
        return 0
    fi

    # Check if systemd user services are available
    if systemctl --user status >/dev/null 2>&1; then
        log_info "Detected: systemd user services available"
        INSTALL_MODE="$MODE_SYSTEMD_USER"
        return 0
    fi

    # Fall back to portable mode
    log_warning "No elevated privileges detected, using portable mode"
    INSTALL_MODE="$MODE_PORTABLE"
    return 0
}

################################################################################
# Path Configuration
################################################################################

configure_paths() {
    log_info "Configuring installation paths for mode: $INSTALL_MODE"

    case "$INSTALL_MODE" in
        "$MODE_ROOT")
            INSTALL_DIR="/opt/netopt"
            CONFIG_DIR="/etc/netopt"
            SERVICE_DIR="/etc/systemd/system"
            BIN_DIR="/usr/local/bin"
            ;;

        "$MODE_SYSTEMD_USER")
            INSTALL_DIR="$HOME/.local/share/netopt"
            CONFIG_DIR="$HOME/.config/netopt"
            SERVICE_DIR="$HOME/.config/systemd/user"
            BIN_DIR="$HOME/.local/bin"
            ;;

        "$MODE_PORTABLE")
            INSTALL_DIR="$HOME/.netopt"
            CONFIG_DIR="$HOME/.netopt/config"
            SERVICE_DIR="$HOME/.netopt/services"
            BIN_DIR="$HOME/.netopt/bin"
            ;;

        *)
            log_error "Unknown installation mode: $INSTALL_MODE"
            return 1
            ;;
    esac

    log_success "Paths configured:"
    log_info "  Install directory: $INSTALL_DIR"
    log_info "  Config directory:  $CONFIG_DIR"
    log_info "  Service directory: $SERVICE_DIR"
    log_info "  Binary directory:  $BIN_DIR"
}

################################################################################
# Directory Creation
################################################################################

create_directories() {
    log_info "Creating installation directories..."

    local dirs=("$INSTALL_DIR" "$CONFIG_DIR" "$SERVICE_DIR" "$BIN_DIR")

    for dir in "${dirs[@]}"; do
        if [[ "$INSTALL_MODE" == "$MODE_ROOT" ]] && [[ $EUID -ne 0 ]]; then
            sudo mkdir -p "$dir"
            sudo chown "$USER:$USER" "$dir"
        else
            mkdir -p "$dir"
        fi
        log_success "Created: $dir"
    done

    # Create additional subdirectories
    mkdir -p "$INSTALL_DIR/lib/safety"
    mkdir -p "$INSTALL_DIR/lib/installer"
    mkdir -p "$INSTALL_DIR/logs"
    mkdir -p "$INSTALL_DIR/checkpoints"
}

################################################################################
# Capability Detection
################################################################################

check_capabilities() {
    log_info "Checking system capabilities..."

    local missing_caps=()

    # Check for required commands
    local required_cmds=("ip" "tc" "sysctl" "systemctl")
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_caps+=("$cmd")
        fi
    done

    # Check for network namespace support
    if [[ "$INSTALL_MODE" == "$MODE_ROOT" ]]; then
        if ! ip netns list >/dev/null 2>&1; then
            log_warning "Network namespace support not available"
        fi
    fi

    # Check for cgroup support
    if [[ -d /sys/fs/cgroup ]]; then
        log_success "cgroup support available"
    else
        log_warning "cgroup support not available"
    fi

    if [[ ${#missing_caps[@]} -gt 0 ]]; then
        log_error "Missing required capabilities: ${missing_caps[*]}"
        return 1
    fi

    log_success "All required capabilities present"
    return 0
}

################################################################################
# Dependency Installation
################################################################################

install_dependencies() {
    log_info "Checking dependencies..."

    if [[ "$INSTALL_MODE" != "$MODE_ROOT" ]]; then
        log_warning "Cannot install system dependencies in non-root mode"
        return 0
    fi

    # Detect package manager
    local pkg_manager=""
    if command -v apt-get >/dev/null 2>&1; then
        pkg_manager="apt"
    elif command -v dnf >/dev/null 2>&1; then
        pkg_manager="dnf"
    elif command -v yum >/dev/null 2>&1; then
        pkg_manager="yum"
    elif command -v pacman >/dev/null 2>&1; then
        pkg_manager="pacman"
    else
        log_warning "Unknown package manager, skipping dependency installation"
        return 0
    fi

    log_info "Detected package manager: $pkg_manager"

    local packages=("iproute2" "ethtool" "tc" "sysstat")

    case "$pkg_manager" in
        apt)
            sudo apt-get update
            sudo apt-get install -y "${packages[@]}"
            ;;
        dnf|yum)
            sudo "$pkg_manager" install -y "${packages[@]}"
            ;;
        pacman)
            sudo pacman -Sy --noconfirm "${packages[@]}"
            ;;
    esac

    log_success "Dependencies installed"
}

################################################################################
# File Installation
################################################################################

install_files() {
    log_info "Installing NETOPT files..."

    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

    # Copy main script
    if [[ -f "$source_dir/network-optimize.sh" ]]; then
        cp "$source_dir/network-optimize.sh" "$INSTALL_DIR/netopt.sh"
        chmod +x "$INSTALL_DIR/netopt.sh"
        log_success "Installed main script"
    else
        log_error "Main script not found: $source_dir/network-optimize.sh"
        return 1
    fi

    # Copy library files
    if [[ -d "$source_dir/lib" ]]; then
        cp -r "$source_dir/lib/"* "$INSTALL_DIR/lib/"
        chmod +x "$INSTALL_DIR/lib/safety/"*.sh
        chmod +x "$INSTALL_DIR/lib/installer/"*.sh
        log_success "Installed library files"
    fi

    # Create symlink in bin directory
    if [[ "$INSTALL_MODE" == "$MODE_ROOT" ]] && [[ $EUID -ne 0 ]]; then
        sudo ln -sf "$INSTALL_DIR/netopt.sh" "$BIN_DIR/netopt"
    else
        ln -sf "$INSTALL_DIR/netopt.sh" "$BIN_DIR/netopt"
    fi
    log_success "Created command symlink"

    # Add to PATH if needed
    if [[ "$INSTALL_MODE" != "$MODE_ROOT" ]]; then
        if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
            log_info "Adding $BIN_DIR to PATH in ~/.bashrc"
            echo "" >> "$HOME/.bashrc"
            echo "# NETOPT path" >> "$HOME/.bashrc"
            echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$HOME/.bashrc"
        fi
    fi
}

################################################################################
# Service Installation
################################################################################

install_service() {
    log_info "Installing systemd service..."

    local service_file="$SERVICE_DIR/netopt.service"
    local use_sudo=""

    if [[ "$INSTALL_MODE" == "$MODE_ROOT" ]] && [[ $EUID -ne 0 ]]; then
        use_sudo="sudo"
    fi

    # Generate service file based on mode
    if [[ "$INSTALL_MODE" == "$MODE_SYSTEMD_USER" ]]; then
        cat > "$service_file" <<EOF
[Unit]
Description=NETOPT Network Optimization (User Service)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$INSTALL_DIR/netopt.sh --apply
StandardOutput=journal
StandardError=journal
RemainAfterExit=yes

[Install]
WantedBy=default.target
EOF
    else
        $use_sudo tee "$service_file" > /dev/null <<EOF
[Unit]
Description=NETOPT Network Optimization
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$INSTALL_DIR/netopt.sh --apply
StandardOutput=journal
StandardError=journal
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    fi

    log_success "Service file created: $service_file"

    # Reload systemd and enable service
    if [[ "$INSTALL_MODE" == "$MODE_SYSTEMD_USER" ]]; then
        systemctl --user daemon-reload
        systemctl --user enable netopt.service
        log_success "Service enabled (user mode)"
    elif [[ "$INSTALL_MODE" == "$MODE_ROOT" ]]; then
        $use_sudo systemctl daemon-reload
        $use_sudo systemctl enable netopt.service
        log_success "Service enabled (system mode)"
    fi
}

################################################################################
# Configuration File Creation
################################################################################

create_config() {
    log_info "Creating default configuration..."

    local config_file="$CONFIG_DIR/netopt.conf"

    cat > "$config_file" <<EOF
# NETOPT Configuration File
# Installation mode: $INSTALL_MODE

# Installation paths
INSTALL_DIR=$INSTALL_DIR
CONFIG_DIR=$CONFIG_DIR
LOG_DIR=$INSTALL_DIR/logs
CHECKPOINT_DIR=$INSTALL_DIR/checkpoints

# Optimization levels
DEFAULT_PROFILE=balanced
# Options: conservative, balanced, aggressive

# Safety features
ENABLE_CHECKPOINTS=true
CHECKPOINT_RETENTION=10
ENABLE_WATCHDOG=true
WATCHDOG_TIMEOUT=300

# Logging
LOG_LEVEL=info
# Options: debug, info, warning, error

# Auto-apply on boot
AUTO_APPLY_ON_BOOT=true
EOF

    log_success "Configuration created: $config_file"
}

################################################################################
# Post-Installation
################################################################################

post_install() {
    log_info "Running post-installation tasks..."

    # Create initial checkpoint
    if [[ -f "$INSTALL_DIR/lib/safety/checkpoint.sh" ]]; then
        source "$INSTALL_DIR/lib/safety/checkpoint.sh"
        create_checkpoint "initial" "Initial system state before NETOPT"
    fi

    # Display installation summary
    echo ""
    echo "========================================"
    log_success "NETOPT Installation Complete!"
    echo "========================================"
    echo ""
    echo "Installation Mode: $INSTALL_MODE"
    echo "Installation Directory: $INSTALL_DIR"
    echo "Configuration: $CONFIG_DIR/netopt.conf"
    echo ""

    case "$INSTALL_MODE" in
        "$MODE_ROOT")
            echo "To start NETOPT:"
            echo "  sudo systemctl start netopt.service"
            echo ""
            echo "To enable on boot:"
            echo "  sudo systemctl enable netopt.service"
            ;;

        "$MODE_SYSTEMD_USER")
            echo "To start NETOPT:"
            echo "  systemctl --user start netopt.service"
            echo ""
            echo "Service will start automatically on login"
            ;;

        "$MODE_PORTABLE")
            echo "To run NETOPT:"
            echo "  $BIN_DIR/netopt --apply"
            echo ""
            echo "Add to your shell profile for auto-start"
            ;;
    esac

    echo ""
    echo "Available commands:"
    echo "  netopt --apply          Apply optimizations"
    echo "  netopt --restore        Restore original settings"
    echo "  netopt --status         Show current status"
    echo "  netopt --checkpoint     Create system checkpoint"
    echo ""
}

################################################################################
# Main Installation Flow
################################################################################

main() {
    log_info "Starting NETOPT Smart Installer..."
    echo ""

    # Detect privileges and capabilities
    detect_privileges
    configure_paths
    check_capabilities

    # Confirm installation
    echo ""
    log_warning "Installation mode: $INSTALL_MODE"
    log_warning "Target directory: $INSTALL_DIR"
    echo ""
    read -p "Continue with installation? [y/N] " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi

    # Execute installation
    create_directories
    install_dependencies
    install_files
    install_service
    create_config
    post_install

    log_success "Installation completed successfully!"
}

# Export functions for sourcing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
