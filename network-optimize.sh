#!/bin/bash
# Dynamic Network Optimization and Load Balancing Script
# Automatically detects, tests, and balances across all active connections

# Configuration
CONFIG_DIR="/var/lib/network-optimize"
BACKUP_FILE="$CONFIG_DIR/route-backup.conf"
STATE_FILE="$CONFIG_DIR/current-state.conf"
LOG_FILE="/var/log/network-optimize.log"

# Connection type priorities (lower = higher priority)
PRIORITY_ETHERNET=10
PRIORITY_WIFI=20
PRIORITY_MOBILE=30
PRIORITY_UNKNOWN=40

# Latency weight calculation (lower latency = higher weight)
MAX_LATENCY=200  # ms - connections slower than this get weight 1

# Functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

detect_interface_type() {
    local iface=$1

    # Ethernet: en*, eth*
    if [[ $iface =~ ^(en|eth) ]]; then
        echo "ethernet"
        return $PRIORITY_ETHERNET
    fi

    # WiFi: wl*, wlan*
    if [[ $iface =~ ^(wl|wlan) ]]; then
        echo "wifi"
        return $PRIORITY_WIFI
    fi

    # Mobile: ppp*, wwan*, usb*
    if [[ $iface =~ ^(ppp|wwan|usb) ]]; then
        echo "mobile"
        return $PRIORITY_MOBILE
    fi

    echo "unknown"
    return $PRIORITY_UNKNOWN
}

test_gateway_latency() {
    local gateway=$1
    local iface=$2

    # Send 3 pings with 1 second timeout each
    local result=$(ping -c 3 -W 1 -I "$iface" "$gateway" 2>/dev/null | grep "rtt min/avg/max" | awk -F'/' '{print $5}')

    if [ -z "$result" ]; then
        return 1  # Failed
    fi

    # Return average latency in ms (rounded)
    echo "${result%.*}"
    return 0
}

calculate_weight() {
    local latency=$1
    local priority=$2

    # Base weight from latency (inverted: lower latency = higher weight)
    # Formula: weight = (MAX_LATENCY - latency) / 10, minimum 1
    local latency_weight=$(( (MAX_LATENCY - latency) / 10 ))
    [ $latency_weight -lt 1 ] && latency_weight=1
    [ $latency_weight -gt 20 ] && latency_weight=20

    # Apply priority multiplier (ethernet gets boost, mobile gets penalty)
    case $priority in
        $PRIORITY_ETHERNET) latency_weight=$((latency_weight * 2)) ;;
        $PRIORITY_WIFI) latency_weight=$((latency_weight * 1)) ;;
        $PRIORITY_MOBILE) latency_weight=$((latency_weight / 2)) ;;
    esac

    [ $latency_weight -lt 1 ] && latency_weight=1
    echo $latency_weight
}

backup_routes() {
    mkdir -p "$CONFIG_DIR"
    log "Backing up current routes..."
    ip route show > "$BACKUP_FILE"
}

restore_routes() {
    if [ ! -f "$BACKUP_FILE" ]; then
        log "ERROR: No backup file found at $BACKUP_FILE"
        return 1
    fi

    log "Restoring routes from backup..."

    # Clear current routes
    while ip route del default 2>/dev/null; do :; done

    # Restore from backup with validation
    while IFS= read -r route; do
        if [[ $route =~ ^default ]]; then
            # Validate route format to prevent command injection
            if [[ $route =~ ^default[[:space:]]+(via|dev|scope|proto|metric|src)[[:space:]] ]]; then
                ip route add $route 2>/dev/null || log "Warning: Failed to restore route: $route"
            else
                log "Warning: Skipping invalid route format: $route"
            fi
        fi
    done < "$BACKUP_FILE"

    log "Routes restored successfully"
    ip route show default
}

save_state() {
    mkdir -p "$CONFIG_DIR"
    cat > "$STATE_FILE" <<EOF
# Network Optimize State - $(date)
INTERFACES=$1
TOTAL_CONNECTIONS=$2
EOF
}

# Parse command line arguments
case "${1:-}" in
    --restore)
        restore_routes
        exit 0
        ;;
    --help|-h)
        echo "Network Optimization Script"
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --restore    Restore previous routing configuration"
        echo "  --help       Show this help message"
        exit 0
        ;;
esac

# Main script
log "=== Dynamic Network Optimizer Starting ==="
mkdir -p "$CONFIG_DIR"

# Backup current configuration
backup_routes

log "Detecting active connections..."

# Remove all existing default routes
log "Clearing old routes..."
while ip route del default 2>/dev/null; do :; done

# Discover and test network interfaces
declare -A CONNECTIONS
ROUTE_COUNT=0

# Get all active interfaces (excluding loopback, docker, and virtual interfaces)
for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "^lo$\|^docker\|^veth\|^br-\|^virbr"); do
    # Check if interface is UP
    if ! ip link show "$iface" 2>/dev/null | grep -q "state UP"; then
        continue
    fi

    # Try to find the gateway for this interface
    GATEWAY=$(ip route show dev "$iface" | grep -oP 'via \K[0-9.]+' | head -1)

    if [ -z "$GATEWAY" ]; then
        continue
    fi

    # Detect interface type and priority
    iface_type=$(detect_interface_type "$iface")
    priority=$?

    log "  Testing: $iface ($iface_type) via $GATEWAY"

    # Test gateway with ping
    latency=$(test_gateway_latency "$GATEWAY" "$iface")

    if [ $? -ne 0 ]; then
        log "    ✗ DEAD - Gateway not responding, skipping"
        continue
    fi

    # Calculate weight based on latency and priority
    weight=$(calculate_weight "$latency" "$priority")

    log "    ✓ ALIVE - Latency: ${latency}ms, Weight: $weight"

    # Store connection info
    CONNECTIONS["$iface"]="$GATEWAY|$weight|$latency|$iface_type"
    ROUTE_COUNT=$((ROUTE_COUNT + 1))
done

# Build and apply multi-path route
if [ $ROUTE_COUNT -gt 0 ]; then
    log "Creating load-balanced route with $ROUTE_COUNT connection(s)..."

    NEXTHOPS=""
    IFACE_LIST=""

    # Sort by weight (highest first) and build route
    for iface in "${!CONNECTIONS[@]}"; do
        IFS='|' read -r gateway weight latency iface_type <<< "${CONNECTIONS[$iface]}"
        NEXTHOPS="$NEXTHOPS nexthop via $gateway dev $iface weight $weight"
        IFACE_LIST="$IFACE_LIST $iface($iface_type:${latency}ms:w$weight)"
    done

    # Apply the route (NEXTHOPS is intentionally unquoted - contains multiple nexthop arguments)
    # shellcheck disable=SC2086
    if ip route add default scope global $NEXTHOPS 2>/dev/null; then
        log "✓ Load balancing enabled!"
        log "  Connections:$IFACE_LIST"
        save_state "$IFACE_LIST" "$ROUTE_COUNT"
    else
        log "✗ Failed to apply route, restoring backup..."
        restore_routes
        exit 1
    fi
else
    log "⚠ No active connections found. Restoring previous routes..."
    restore_routes
    exit 1
fi

# Optimize TCP parameters
log "Applying TCP optimizations..."
sysctl -w net.ipv4.tcp_fastopen=3 >/dev/null 2>&1
sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1
sysctl -w net.core.rmem_max=16777216 >/dev/null 2>&1
sysctl -w net.core.wmem_max=16777216 >/dev/null 2>&1
sysctl -w net.ipv4.tcp_no_metrics_save=1 >/dev/null 2>&1
log "✓ TCP optimizations applied"

# Configure fast DNS (preserve if NetworkManager controls it)
if [ -w /etc/resolv.conf ]; then
    log "Configuring fast DNS servers..."

    # Skip if resolv.conf is a symlink (managed by system)
    if [ -L /etc/resolv.conf ]; then
        log "  Skipping: /etc/resolv.conf is managed by system (symlink)"
    # Check if dnsmasq is running
    elif systemctl is-active --quiet dnsmasq 2>/dev/null; then
        log "  Using dnsmasq for DNS caching (127.0.0.1)"
    else
        # Backup existing DNS configuration
        if [ -f /etc/resolv.conf ]; then
            cp -p /etc/resolv.conf "$CONFIG_DIR/resolv.conf.backup" 2>/dev/null || \
                log "Warning: Could not backup DNS configuration"
        fi

        cat > /etc/resolv.conf <<EOF
# Optimized DNS - Fast resolvers only
# Backup saved to: $CONFIG_DIR/resolv.conf.backup
nameserver 1.1.1.1
nameserver 1.0.0.1
nameserver 8.8.8.8
EOF
        log "✓ DNS optimized (Cloudflare + Google)"
    fi
fi

log ""
log "=== Current Configuration ==="
ip route show default | tee -a "$LOG_FILE"
log ""
log "✓ All done! Your connections are now intelligently load-balanced."
