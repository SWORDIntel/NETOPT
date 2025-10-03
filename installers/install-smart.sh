#!/bin/bash
################################################################################
# NETOPT Smart Installer - Entry Point
# Intelligent installation with automatic privilege detection
################################################################################

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

################################################################################
# Banner
################################################################################

show_banner() {
    cat <<'EOF'
    _   ____________  __________
   / | / / ____/_  __/ __ / __ \/_  __/
  /  |/ / __/   / / / / / / /_/ / / /
 / /|  / /___  / / / /_/ / ____/ / /
/_/ |_/_____/ /_/  \____/_/     /_/

Network Optimization Toolkit - Smart Installer
EOF
    echo ""
}

################################################################################
# System Information
################################################################################

show_system_info() {
    echo -e "${BOLD}System Information:${NC}"
    echo "  OS: $(uname -s) $(uname -r)"
    echo "  Hostname: $(hostname)"
    echo "  User: $USER (UID: $UID)"

    if [[ $EUID -eq 0 ]]; then
        echo -e "  Privileges: ${GREEN}Root${NC}"
    elif sudo -n true 2>/dev/null; then
        echo -e "  Privileges: ${GREEN}Sudo (passwordless)${NC}"
    else
        echo -e "  Privileges: ${YELLOW}User (limited)${NC}"
    fi

    echo ""
}

################################################################################
# Pre-Installation Checks
################################################################################

check_requirements() {
    echo -e "${BLUE}Checking system requirements...${NC}"

    local missing_tools=()
    local required_tools=("bash" "ip" "sysctl")

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${RED}Error: Missing required tools: ${missing_tools[*]}${NC}"
        echo "Please install the required tools and try again."
        return 1
    fi

    # Check for optional tools
    local optional_tools=("tc" "ethtool" "systemctl")
    local missing_optional=()

    for tool in "${optional_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_optional+=("$tool")
        fi
    done

    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Warning: Some optional tools are missing: ${missing_optional[*]}${NC}"
        echo "Some features may be limited."
    fi

    echo -e "${GREEN}System requirements check passed${NC}"
    echo ""
    return 0
}

################################################################################
# Installation Options
################################################################################

show_installation_options() {
    cat <<EOF
${BOLD}Installation Options:${NC}

1. ${GREEN}Automatic${NC} - Detect privileges and install automatically
2. ${YELLOW}Custom${NC} - Choose installation mode manually
3. ${CYAN}Advanced${NC} - Configure all options
4. ${RED}Exit${NC}

EOF
}

select_installation_mode() {
    local mode=""

    while true; do
        show_installation_options
        read -p "Select installation option [1-4]: " -n 1 -r choice
        echo ""

        case "$choice" in
            1)
                mode="automatic"
                break
                ;;
            2)
                mode="custom"
                break
                ;;
            3)
                mode="advanced"
                break
                ;;
            4)
                echo "Installation cancelled."
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please select 1-4.${NC}"
                echo ""
                ;;
        esac
    done

    echo "$mode"
}

################################################################################
# Custom Installation
################################################################################

custom_installation() {
    echo ""
    echo -e "${BOLD}Custom Installation Mode${NC}"
    echo ""
    echo "Select installation type:"
    echo "  1. System-wide (requires root/sudo)"
    echo "  2. User service (systemd --user)"
    echo "  3. Portable (user directory)"
    echo ""

    read -p "Select [1-3]: " -n 1 -r choice
    echo ""

    case "$choice" in
        1)
            export FORCE_MODE="root"
            ;;
        2)
            export FORCE_MODE="systemd-user"
            ;;
        3)
            export FORCE_MODE="portable"
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            return 1
            ;;
    esac
}

################################################################################
# Advanced Installation
################################################################################

advanced_installation() {
    echo ""
    echo -e "${BOLD}Advanced Installation Configuration${NC}"
    echo ""

    # Installation mode
    echo "1. Installation Mode:"
    echo "   1) System-wide (root)"
    echo "   2) User service (systemd --user)"
    echo "   3) Portable (no systemd)"
    read -p "   Select [1-3]: " -n 1 -r mode_choice
    echo ""

    case "$mode_choice" in
        1) export FORCE_MODE="root" ;;
        2) export FORCE_MODE="systemd-user" ;;
        3) export FORCE_MODE="portable" ;;
        *) export FORCE_MODE="auto" ;;
    esac

    # Safety features
    echo ""
    echo "2. Safety Features:"
    read -p "   Enable automatic checkpoints? [Y/n]: " -n 1 -r checkpoint_choice
    echo ""
    export ENABLE_CHECKPOINTS="${checkpoint_choice:-y}"

    read -p "   Enable remote safety (SSH watchdog)? [Y/n]: " -n 1 -r watchdog_choice
    echo ""
    export ENABLE_WATCHDOG="${watchdog_choice:-y}"

    # Optimization profile
    echo ""
    echo "3. Default Optimization Profile:"
    echo "   1) Conservative (safe, minimal changes)"
    echo "   2) Balanced (recommended)"
    echo "   3) Aggressive (maximum performance)"
    read -p "   Select [1-3]: " -n 1 -r profile_choice
    echo ""

    case "$profile_choice" in
        1) export DEFAULT_PROFILE="conservative" ;;
        2) export DEFAULT_PROFILE="balanced" ;;
        3) export DEFAULT_PROFILE="aggressive" ;;
        *) export DEFAULT_PROFILE="balanced" ;;
    esac

    # Auto-apply on boot
    echo ""
    read -p "4. Apply optimizations automatically on boot? [Y/n]: " -n 1 -r autoboot_choice
    echo ""
    export AUTO_APPLY_ON_BOOT="${autoboot_choice:-y}"

    echo ""
    echo -e "${GREEN}Advanced configuration complete${NC}"
    echo ""
}

################################################################################
# Installation Summary
################################################################################

show_installation_summary() {
    echo ""
    echo "=========================================="
    echo -e "${BOLD}Installation Summary${NC}"
    echo "=========================================="
    echo ""
    echo "Mode: ${FORCE_MODE:-automatic}"
    echo "Checkpoints: ${ENABLE_CHECKPOINTS:-enabled}"
    echo "Watchdog: ${ENABLE_WATCHDOG:-enabled}"
    echo "Profile: ${DEFAULT_PROFILE:-balanced}"
    echo "Auto-boot: ${AUTO_APPLY_ON_BOOT:-yes}"
    echo ""
    echo "=========================================="
    echo ""
}

################################################################################
# Main Installation
################################################################################

run_installation() {
    echo -e "${BLUE}Starting installation...${NC}"
    echo ""

    # Source and run the smart installer library
    # Note: We're in installers/ so parent dir is NETOPT root
    local lib_path="$(dirname "$SCRIPT_DIR")/lib/installer/smart-install.sh"
    if [[ -f "$lib_path" ]]; then
        source "$lib_path"

        # Override main function call - we'll call components directly
        detect_privileges
        configure_paths

        echo ""
        read -p "Proceed with installation to $INSTALL_DIR? [y/N] " -n 1 -r
        echo ""

        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            exit 0
        fi

        check_capabilities
        create_directories
        install_dependencies
        install_files
        install_service
        create_config
        post_install

    else
        echo -e "${RED}Error: Smart installer not found!${NC}"
        echo "Please ensure all NETOPT files are present."
        return 1
    fi
}

################################################################################
# Post-Installation Tests
################################################################################

run_post_install_tests() {
    echo ""
    echo -e "${BLUE}Running post-installation tests...${NC}"
    echo ""

    # Test 1: Check if netopt command is available
    if command -v netopt >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Command 'netopt' is available"
    else
        echo -e "${YELLOW}⚠${NC} Command 'netopt' not found in PATH"
        echo "  You may need to restart your shell or source your profile"
    fi

    # Test 2: Check configuration file
    local config_files=(
        "/etc/netopt/netopt.conf"
        "$HOME/.config/netopt/netopt.conf"
        "$HOME/.netopt/config/netopt.conf"
    )

    local config_found=false
    for config in "${config_files[@]}"; do
        if [[ -f "$config" ]]; then
            echo -e "${GREEN}✓${NC} Configuration found: $config"
            config_found=true
            break
        fi
    done

    if [[ "$config_found" != "true" ]]; then
        echo -e "${RED}✗${NC} No configuration file found"
    fi

    # Test 3: Check service status
    if systemctl --user list-unit-files netopt.service >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} User service installed"
    elif systemctl list-unit-files netopt.service >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} System service installed"
    else
        echo -e "${YELLOW}⚠${NC} Service not found (portable mode?)"
    fi

    echo ""
}

################################################################################
# Main Entry Point
################################################################################

main() {
    clear
    show_banner
    echo ""

    # Check if running from correct directory
    if [[ ! -f "$SCRIPT_DIR/network-optimize.sh" ]]; then
        echo -e "${RED}Error: Main script not found!${NC}"
        echo "Please run this installer from the NETOPT directory."
        exit 1
    fi

    show_system_info
    check_requirements || exit 1

    # Select installation mode
    local mode=$(select_installation_mode)

    case "$mode" in
        custom)
            custom_installation || exit 1
            ;;
        advanced)
            advanced_installation || exit 1
            ;;
        automatic)
            echo -e "${BLUE}Using automatic installation mode${NC}"
            echo ""
            ;;
    esac

    # Show summary
    show_installation_summary

    # Confirm and install
    read -p "Start installation? [y/N] " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi

    # Run installation
    if run_installation; then
        echo ""
        echo -e "${GREEN}${BOLD}Installation completed successfully!${NC}"

        # Run tests
        run_post_install_tests

        # Final message
        echo ""
        echo "=========================================="
        echo -e "${BOLD}Next Steps:${NC}"
        echo "=========================================="
        echo ""
        echo "1. Review configuration:"
        echo "   - Edit /etc/netopt/netopt.conf (or ~/.config/netopt/netopt.conf)"
        echo ""
        echo "2. Test the installation:"
        echo "   - Run: netopt --status"
        echo ""
        echo "3. Apply optimizations:"
        echo "   - Run: netopt --apply"
        echo "   - Or: sudo systemctl start netopt.service"
        echo ""
        echo "4. View documentation:"
        echo "   - See: docs/INSTALLATION.md"
        echo ""
        echo "=========================================="
        echo ""

    else
        echo ""
        echo -e "${RED}Installation failed!${NC}"
        echo "Please check the errors above and try again."
        exit 1
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
