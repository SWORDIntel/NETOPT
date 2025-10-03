#!/bin/bash
# Network Simulator for Integration Testing
# Creates virtual network interfaces and namespaces for realistic testing

set -e

# Configuration
NETNS_PREFIX="netopt_test"
VETH_PREFIX="veth_test"
BRIDGE_NAME="br_netopt_test"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[SIMULATOR]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Create a network namespace
create_namespace() {
    local ns_name=$1
    log "Creating namespace: $ns_name"
    ip netns add "$ns_name" 2>/dev/null || warn "Namespace $ns_name already exists"
}

# Delete a network namespace
delete_namespace() {
    local ns_name=$1
    log "Deleting namespace: $ns_name"
    ip netns del "$ns_name" 2>/dev/null || warn "Namespace $ns_name does not exist"
}

# Create a veth pair
create_veth_pair() {
    local veth_host=$1
    local veth_ns=$2
    local ns_name=$3

    log "Creating veth pair: $veth_host <-> $veth_ns"

    # Create veth pair
    ip link add "$veth_host" type veth peer name "$veth_ns" || {
        warn "Veth pair already exists, deleting and recreating"
        ip link del "$veth_host" 2>/dev/null || true
        ip link add "$veth_host" type veth peer name "$veth_ns"
    }

    # Move one end to namespace
    ip link set "$veth_ns" netns "$ns_name"

    # Bring up host end
    ip link set "$veth_host" up
}

# Configure interface with IP address
configure_interface() {
    local ns_name=$1
    local iface=$2
    local ip_addr=$3
    local gateway=$4

    log "Configuring $iface in $ns_name with IP $ip_addr"

    # Configure in namespace
    if [ "$ns_name" = "host" ]; then
        ip addr add "$ip_addr" dev "$iface" 2>/dev/null || warn "IP already assigned"
        ip link set "$iface" up
    else
        ip netns exec "$ns_name" ip addr add "$ip_addr" dev "$iface" 2>/dev/null || warn "IP already assigned"
        ip netns exec "$ns_name" ip link set "$iface" up
        ip netns exec "$ns_name" ip link set lo up

        # Add default route if gateway provided
        if [ -n "$gateway" ]; then
            ip netns exec "$ns_name" ip route add default via "$gateway" 2>/dev/null || warn "Default route already exists"
        fi
    fi
}

# Add network latency using tc (traffic control)
add_latency() {
    local iface=$1
    local latency_ms=$2
    local ns_name=${3:-"host"}

    log "Adding ${latency_ms}ms latency to $iface"

    if [ "$ns_name" = "host" ]; then
        tc qdisc add dev "$iface" root netem delay "${latency_ms}ms" 2>/dev/null || \
            warn "Failed to add latency (tc qdisc might already exist)"
    else
        ip netns exec "$ns_name" tc qdisc add dev "$iface" root netem delay "${latency_ms}ms" 2>/dev/null || \
            warn "Failed to add latency (tc qdisc might already exist)"
    fi
}

# Remove latency from interface
remove_latency() {
    local iface=$1
    local ns_name=${2:-"host"}

    log "Removing latency from $iface"

    if [ "$ns_name" = "host" ]; then
        tc qdisc del dev "$iface" root 2>/dev/null || warn "No qdisc to remove"
    else
        ip netns exec "$ns_name" tc qdisc del dev "$iface" root 2>/dev/null || warn "No qdisc to remove"
    fi
}

# Create a bridge
create_bridge() {
    local bridge_name=$1
    local ip_addr=$2

    log "Creating bridge: $bridge_name"

    ip link add name "$bridge_name" type bridge 2>/dev/null || warn "Bridge already exists"
    ip link set "$bridge_name" up

    if [ -n "$ip_addr" ]; then
        ip addr add "$ip_addr" dev "$bridge_name" 2>/dev/null || warn "IP already assigned to bridge"
    fi
}

# Add interface to bridge
add_to_bridge() {
    local bridge_name=$1
    local iface=$2

    log "Adding $iface to bridge $bridge_name"
    ip link set "$iface" master "$bridge_name"
}

# Setup complete multi-interface test environment
setup_multi_interface_env() {
    log "Setting up multi-interface test environment"

    # Create bridge for routing
    create_bridge "$BRIDGE_NAME" "10.0.0.1/24"

    # Setup Ethernet interface (low latency)
    create_namespace "${NETNS_PREFIX}_eth"
    create_veth_pair "${VETH_PREFIX}_eth_host" "${VETH_PREFIX}_eth_ns" "${NETNS_PREFIX}_eth"
    add_to_bridge "$BRIDGE_NAME" "${VETH_PREFIX}_eth_host"
    configure_interface "${NETNS_PREFIX}_eth" "${VETH_PREFIX}_eth_ns" "10.0.0.2/24" "10.0.0.1"
    add_latency "${VETH_PREFIX}_eth_ns" "5" "${NETNS_PREFIX}_eth"

    # Setup WiFi interface (medium latency)
    create_namespace "${NETNS_PREFIX}_wifi"
    create_veth_pair "${VETH_PREFIX}_wifi_host" "${VETH_PREFIX}_wifi_ns" "${NETNS_PREFIX}_wifi"
    add_to_bridge "$BRIDGE_NAME" "${VETH_PREFIX}_wifi_host"
    configure_interface "${NETNS_PREFIX}_wifi" "${VETH_PREFIX}_wifi_ns" "10.0.0.3/24" "10.0.0.1"
    add_latency "${VETH_PREFIX}_wifi_ns" "20" "${NETNS_PREFIX}_wifi"

    # Setup Mobile interface (high latency)
    create_namespace "${NETNS_PREFIX}_mobile"
    create_veth_pair "${VETH_PREFIX}_mobile_host" "${VETH_PREFIX}_mobile_ns" "${NETNS_PREFIX}_mobile"
    add_to_bridge "$BRIDGE_NAME" "${VETH_PREFIX}_mobile_host"
    configure_interface "${NETNS_PREFIX}_mobile" "${VETH_PREFIX}_mobile_ns" "10.0.0.4/24" "10.0.0.1"
    add_latency "${VETH_PREFIX}_mobile_ns" "50" "${NETNS_PREFIX}_mobile"

    log "Multi-interface environment ready!"
    log "  Ethernet: ${VETH_PREFIX}_eth_ns (5ms latency)"
    log "  WiFi: ${VETH_PREFIX}_wifi_ns (20ms latency)"
    log "  Mobile: ${VETH_PREFIX}_mobile_ns (50ms latency)"
}

# Cleanup test environment
cleanup_env() {
    log "Cleaning up test environment"

    # Remove namespaces
    delete_namespace "${NETNS_PREFIX}_eth"
    delete_namespace "${NETNS_PREFIX}_wifi"
    delete_namespace "${NETNS_PREFIX}_mobile"

    # Remove veth pairs (automatically removed with namespace)
    ip link del "${VETH_PREFIX}_eth_host" 2>/dev/null || true
    ip link del "${VETH_PREFIX}_wifi_host" 2>/dev/null || true
    ip link del "${VETH_PREFIX}_mobile_host" 2>/dev/null || true

    # Remove bridge
    ip link set "$BRIDGE_NAME" down 2>/dev/null || true
    ip link del "$BRIDGE_NAME" 2>/dev/null || true

    log "Cleanup complete"
}

# Simulate interface failure
simulate_interface_failure() {
    local iface=$1
    log "Simulating failure on $iface"
    ip link set "$iface" down
}

# Simulate interface recovery
simulate_interface_recovery() {
    local iface=$1
    log "Simulating recovery on $iface"
    ip link set "$iface" up
}

# Show network status
show_status() {
    log "Current network status:"
    echo ""
    echo "Namespaces:"
    ip netns list | grep "$NETNS_PREFIX" || echo "  None"
    echo ""
    echo "Interfaces:"
    ip link show | grep -E "(${VETH_PREFIX}|${BRIDGE_NAME})" || echo "  None"
    echo ""
    echo "Routes in default namespace:"
    ip route show | head -5
}

# Main command handler
case "${1:-}" in
    setup)
        check_root
        setup_multi_interface_env
        ;;
    cleanup)
        check_root
        cleanup_env
        ;;
    status)
        show_status
        ;;
    fail)
        check_root
        if [ -z "$2" ]; then
            error "Usage: $0 fail <interface>"
            exit 1
        fi
        simulate_interface_failure "$2"
        ;;
    recover)
        check_root
        if [ -z "$2" ]; then
            error "Usage: $0 recover <interface>"
            exit 1
        fi
        simulate_interface_recovery "$2"
        ;;
    latency)
        check_root
        if [ -z "$2" ] || [ -z "$3" ]; then
            error "Usage: $0 latency <interface> <ms> [namespace]"
            exit 1
        fi
        add_latency "$2" "$3" "${4:-host}"
        ;;
    *)
        echo "Network Simulator for NETOPT Testing"
        echo ""
        echo "Usage: $0 {setup|cleanup|status|fail|recover|latency}"
        echo ""
        echo "Commands:"
        echo "  setup              - Create complete multi-interface test environment"
        echo "  cleanup            - Remove all test network resources"
        echo "  status             - Show current network status"
        echo "  fail <iface>       - Simulate interface failure"
        echo "  recover <iface>    - Simulate interface recovery"
        echo "  latency <iface> <ms> [ns] - Add latency to interface"
        echo ""
        echo "Example:"
        echo "  $0 setup           # Create test environment"
        echo "  $0 status          # Check what's created"
        echo "  $0 cleanup         # Remove everything"
        exit 1
        ;;
esac
