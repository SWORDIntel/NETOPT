#!/bin/bash
# Network interface detection and analysis for NETOPT
# Handles interface type detection, capability discovery, and state monitoring

# Detect interface type based on naming convention and properties
detect_interface_type() {
    local iface="$1"

    # Check if interface exists
    if [ ! -d "/sys/class/net/$iface" ]; then
        echo "unknown"
        return "${NETOPT_CONFIG[PRIORITY_UNKNOWN]:-40}"
    fi

    # Read interface type from sysfs if available
    local if_type=""
    if [ -f "/sys/class/net/$iface/type" ]; then
        if_type="$(cat "/sys/class/net/$iface/type" 2>/dev/null)"
    fi

    # Check for wireless interface
    if [ -d "/sys/class/net/$iface/wireless" ] || [ -d "/sys/class/net/$iface/phy80211" ]; then
        echo "wifi"
        return "${NETOPT_CONFIG[PRIORITY_WIFI]:-20}"
    fi

    # Ethernet: en*, eth*, eno*, enp*, enx*
    if [[ $iface =~ ^(en|eth) ]]; then
        # Verify it's actually ethernet (type 1 = Ethernet)
        if [ "$if_type" = "1" ]; then
            echo "ethernet"
            return "${NETOPT_CONFIG[PRIORITY_ETHERNET]:-10}"
        fi
    fi

    # WiFi: wl*, wlan*
    if [[ $iface =~ ^(wl|wlan) ]]; then
        echo "wifi"
        return "${NETOPT_CONFIG[PRIORITY_WIFI]:-20}"
    fi

    # Mobile/Cellular: ppp*, wwan*, usb*, wwp*
    if [[ $iface =~ ^(ppp|wwan|usb|wwp) ]]; then
        echo "mobile"
        return "${NETOPT_CONFIG[PRIORITY_MOBILE]:-30}"
    fi

    # Fallback: Check if it's ethernet by interface type
    if [ "$if_type" = "1" ]; then
        echo "ethernet"
        return "${NETOPT_CONFIG[PRIORITY_ETHERNET]:-10}"
    fi

    echo "unknown"
    return "${NETOPT_CONFIG[PRIORITY_UNKNOWN]:-40}"
}

# Get detailed interface information
get_interface_info() {
    local iface="$1"
    local info_type="${2:-all}"

    if [ ! -d "/sys/class/net/$iface" ]; then
        return 1
    fi

    case "$info_type" in
        mac|address)
            cat "/sys/class/net/$iface/address" 2>/dev/null
            ;;
        mtu)
            cat "/sys/class/net/$iface/mtu" 2>/dev/null
            ;;
        speed)
            # Speed in Mbps (only works for ethernet)
            cat "/sys/class/net/$iface/speed" 2>/dev/null
            ;;
        duplex)
            # full, half, or unknown
            cat "/sys/class/net/$iface/duplex" 2>/dev/null
            ;;
        carrier)
            # 1 = link up, 0 = link down
            cat "/sys/class/net/$iface/carrier" 2>/dev/null
            ;;
        operstate)
            # up, down, unknown, dormant, etc.
            cat "/sys/class/net/$iface/operstate" 2>/dev/null
            ;;
        driver)
            # Driver name
            if [ -L "/sys/class/net/$iface/device/driver" ]; then
                basename "$(readlink "/sys/class/net/$iface/device/driver")" 2>/dev/null
            fi
            ;;
        all)
            echo "Interface: $iface"
            echo "  Type: $(detect_interface_type "$iface")"
            echo "  MAC: $(get_interface_info "$iface" mac)"
            echo "  MTU: $(get_interface_info "$iface" mtu)"
            echo "  Speed: $(get_interface_info "$iface" speed) Mbps"
            echo "  Duplex: $(get_interface_info "$iface" duplex)"
            echo "  Carrier: $(get_interface_info "$iface" carrier)"
            echo "  State: $(get_interface_info "$iface" operstate)"
            echo "  Driver: $(get_interface_info "$iface" driver)"
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

# Check if interface is physically connected (has carrier)
has_carrier() {
    local iface="$1"
    local carrier

    carrier="$(get_interface_info "$iface" carrier 2>/dev/null)"
    [ "$carrier" = "1" ]
}

# Check if interface is operationally up
is_interface_up() {
    local iface="$1"

    ip link show "$iface" 2>/dev/null | grep -q "state UP"
}

# Get all active network interfaces (excluding filtered ones)
get_active_interfaces() {
    local exclude_pattern="${1:-${NETOPT_CONFIG[EXCLUDE_INTERFACES]:-^lo$|^docker|^veth|^br-|^virbr}}"
    local interfaces=()

    # Get all interfaces
    for iface in /sys/class/net/*; do
        iface="$(basename "$iface")"

        # Apply exclusion filter
        if [[ $iface =~ $exclude_pattern ]]; then
            continue
        fi

        # Check if interface is up
        if ! is_interface_up "$iface"; then
            continue
        fi

        interfaces+=("$iface")
    done

    printf '%s\n' "${interfaces[@]}"
}

# Get gateway for a specific interface
get_interface_gateway() {
    local iface="$1"

    # Try to get gateway from routing table
    ip route show dev "$iface" 2>/dev/null | grep -oP 'via \K[0-9.]+' | head -1
}

# Get IP address(es) for an interface
get_interface_ip() {
    local iface="$1"
    local version="${2:-4}"  # 4 or 6

    case "$version" in
        4)
            ip -4 addr show "$iface" 2>/dev/null | grep -oP 'inet \K[0-9.]+' | head -1
            ;;
        6)
            ip -6 addr show "$iface" 2>/dev/null | grep -oP 'inet6 \K[0-9a-f:]+' | head -1
            ;;
        *)
            return 1
            ;;
    esac
}

# Test gateway latency
test_gateway_latency() {
    local gateway="$1"
    local iface="$2"
    local ping_count="${3:-${NETOPT_CONFIG[PING_COUNT]:-3}}"
    local ping_timeout="${4:-${NETOPT_CONFIG[PING_TIMEOUT]:-1}}"

    # Send pings with timeout
    local result
    result=$(ping -c "$ping_count" -W "$ping_timeout" -I "$iface" "$gateway" 2>/dev/null | \
             grep "rtt min/avg/max" | awk -F'/' '{print $5}')

    if [ -z "$result" ]; then
        return 1  # Failed
    fi

    # Return average latency in ms (rounded)
    echo "${result%.*}"
    return 0
}

# Test internet connectivity through interface
test_internet_connectivity() {
    local iface="$1"
    local test_host="${2:-1.1.1.1}"

    # Try to ping a known public IP
    ping -c 1 -W 2 -I "$iface" "$test_host" >/dev/null 2>&1
}

# Get bandwidth usage statistics for interface
get_interface_stats() {
    local iface="$1"
    local stat_type="${2:-both}"

    if [ ! -d "/sys/class/net/$iface/statistics" ]; then
        return 1
    fi

    local rx_bytes tx_bytes
    rx_bytes="$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo 0)"
    tx_bytes="$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo 0)"

    case "$stat_type" in
        rx|received)
            echo "$rx_bytes"
            ;;
        tx|transmitted)
            echo "$tx_bytes"
            ;;
        both|total)
            echo "RX: $rx_bytes TX: $tx_bytes Total: $((rx_bytes + tx_bytes))"
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

# Calculate interface utilization percentage
calculate_interface_utilization() {
    local iface="$1"
    local interval="${2:-1}"  # seconds

    local rx1 tx1 rx2 tx2

    rx1="$(get_interface_stats "$iface" rx)"
    tx1="$(get_interface_stats "$iface" tx)"

    sleep "$interval"

    rx2="$(get_interface_stats "$iface" rx)"
    tx2="$(get_interface_stats "$iface" tx)"

    local rx_diff=$((rx2 - rx1))
    local tx_diff=$((tx2 - tx1))
    local total_bytes=$((rx_diff + tx_diff))

    # Convert to bits per second
    local bps=$((total_bytes * 8 / interval))

    # Get interface speed (in Mbps)
    local speed_mbps
    speed_mbps="$(get_interface_info "$iface" speed 2>/dev/null)"

    if [ -n "$speed_mbps" ] && [ "$speed_mbps" -gt 0 ]; then
        local max_bps=$((speed_mbps * 1000000))
        local utilization=$((bps * 100 / max_bps))
        echo "$utilization"
    else
        echo "unknown"
    fi
}

# Detect if interface supports multiqueue
supports_multiqueue() {
    local iface="$1"

    [ -d "/sys/class/net/$iface/queues" ] && \
    [ "$(find "/sys/class/net/$iface/queues" -name "tx-*" | wc -l)" -gt 1 ]
}

# Get optimal MTU for interface
get_optimal_mtu() {
    local iface="$1"
    local gateway

    gateway="$(get_interface_gateway "$iface")"

    if [ -z "$gateway" ]; then
        echo "1500"  # Default
        return
    fi

    # Path MTU discovery using ping
    local mtu=1500
    while [ $mtu -ge 1280 ]; do
        if ping -c 1 -W 1 -M do -s $((mtu - 28)) -I "$iface" "$gateway" >/dev/null 2>&1; then
            echo "$mtu"
            return
        fi
        mtu=$((mtu - 8))
    done

    echo "1280"  # Minimum IPv6 MTU
}
