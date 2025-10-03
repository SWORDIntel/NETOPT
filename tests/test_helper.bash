#!/usr/bin/env bash
# Test helper functions for BATS tests

# Set the root directory of the NETOPT project
export NETOPT_ROOT="${NETOPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Mock functions for testing

# Mock ip command for testing
mock_ip() {
    local cmd=$1
    shift

    case "$cmd" in
        "link")
            if [ "$1" = "show" ]; then
                if [ -n "$MOCK_IP_LINK_OUTPUT" ]; then
                    echo "$MOCK_IP_LINK_OUTPUT"
                else
                    echo "1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN"
                    echo "2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP"
                    echo "3: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP"
                fi
            fi
            ;;
        "route")
            if [ "$1" = "show" ]; then
                if [ -n "$MOCK_IP_ROUTE_OUTPUT" ]; then
                    echo "$MOCK_IP_ROUTE_OUTPUT"
                else
                    echo "default via 192.168.1.1 dev eth0"
                    echo "192.168.1.0/24 dev eth0 proto kernel scope link src 192.168.1.100"
                fi
            fi
            ;;
        "-o")
            if [ "$1" = "link" ] && [ "$2" = "show" ]; then
                if [ -n "$MOCK_IP_LINK_OUTPUT" ]; then
                    echo "$MOCK_IP_LINK_OUTPUT"
                else
                    echo "1: lo: <LOOPBACK,UP,LOWER_UP>"
                    echo "2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP>"
                    echo "3: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP>"
                fi
            fi
            ;;
    esac
}

# Mock ping command for testing
mock_ping() {
    local count=3
    local timeout=1
    local interface=""
    local target=""

    # Parse ping arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            -c) count=$2; shift 2 ;;
            -W) timeout=$2; shift 2 ;;
            -I) interface=$2; shift 2 ;;
            *) target=$1; shift ;;
        esac
    done

    # Return mock latency based on interface or target
    if [ -n "$MOCK_PING_FAIL" ]; then
        return 1
    fi

    if [ -n "$MOCK_PING_LATENCY" ]; then
        echo "PING $target ($target) 56(84) bytes of data."
        echo "64 bytes from $target: icmp_seq=1 ttl=64 time=${MOCK_PING_LATENCY} ms"
        echo "64 bytes from $target: icmp_seq=2 ttl=64 time=${MOCK_PING_LATENCY} ms"
        echo "64 bytes from $target: icmp_seq=3 ttl=64 time=${MOCK_PING_LATENCY} ms"
        echo ""
        echo "--- $target ping statistics ---"
        echo "3 packets transmitted, 3 received, 0% packet loss, time 2003ms"
        echo "rtt min/avg/max/mdev = ${MOCK_PING_LATENCY}/${MOCK_PING_LATENCY}/${MOCK_PING_LATENCY}/0.000 ms"
        return 0
    fi

    # Default behavior - return reasonable latency
    echo "PING $target ($target) 56(84) bytes of data."
    echo "64 bytes from $target: icmp_seq=1 ttl=64 time=10.5 ms"
    echo "64 bytes from $target: icmp_seq=2 ttl=64 time=10.3 ms"
    echo "64 bytes from $target: icmp_seq=3 ttl=64 time=10.7 ms"
    echo ""
    echo "--- $target ping statistics ---"
    echo "3 packets transmitted, 3 received, 0% packet loss, time 2003ms"
    echo "rtt min/avg/max/mdev = 10.3/10.5/10.7/0.200 ms"
}

# Mock sysctl command
mock_sysctl() {
    local key=$1
    if [ -n "$MOCK_SYSCTL_OUTPUT" ]; then
        echo "$MOCK_SYSCTL_OUTPUT"
    fi
    return 0
}

# Setup network namespace for testing
setup_netns() {
    local ns_name=$1
    if [ -z "$ns_name" ]; then
        ns_name="test_ns_$$"
    fi

    # Create network namespace
    ip netns add "$ns_name" 2>/dev/null || true
    echo "$ns_name"
}

# Cleanup network namespace
cleanup_netns() {
    local ns_name=$1
    if [ -n "$ns_name" ]; then
        ip netns del "$ns_name" 2>/dev/null || true
    fi
}

# Create virtual interface pair
create_veth_pair() {
    local name1=$1
    local name2=$2
    ip link add "$name1" type veth peer name "$name2" 2>/dev/null || true
}

# Delete virtual interface pair
delete_veth_pair() {
    local name=$1
    ip link del "$name" 2>/dev/null || true
}

# Check if running as root
is_root() {
    [ "$(id -u)" -eq 0 ]
}

# Skip test if not root
require_root() {
    if ! is_root; then
        skip "This test requires root privileges"
    fi
}

# Check if a command exists
has_command() {
    command -v "$1" >/dev/null 2>&1
}

# Skip test if command is not available
require_command() {
    if ! has_command "$1"; then
        skip "This test requires $1 to be installed"
    fi
}

# Create a mock gateway that responds to ping
setup_mock_gateway() {
    local ns_name=$1
    local ip_addr=$2

    # This would typically set up a namespace with a responding interface
    # For unit tests, we'll rely on mocks instead
    return 0
}

# Assert that a string contains a substring
assert_contains() {
    local haystack=$1
    local needle=$2
    if [[ "$haystack" != *"$needle"* ]]; then
        echo "Expected '$haystack' to contain '$needle'"
        return 1
    fi
}

# Assert that a string does not contain a substring
assert_not_contains() {
    local haystack=$1
    local needle=$2
    if [[ "$haystack" == *"$needle"* ]]; then
        echo "Expected '$haystack' to not contain '$needle'"
        return 1
    fi
}

# Assert that a number is greater than another
assert_greater_than() {
    local a=$1
    local b=$2
    if [ "$a" -le "$b" ]; then
        echo "Expected $a to be greater than $b"
        return 1
    fi
}

# Assert that a number is less than another
assert_less_than() {
    local a=$1
    local b=$2
    if [ "$a" -ge "$b" ]; then
        echo "Expected $a to be less than $b"
        return 1
    fi
}

# Export functions for use in tests
export -f mock_ip
export -f mock_ping
export -f mock_sysctl
export -f setup_netns
export -f cleanup_netns
export -f create_veth_pair
export -f delete_veth_pair
export -f is_root
export -f require_root
export -f has_command
export -f require_command
export -f setup_mock_gateway
export -f assert_contains
export -f assert_not_contains
export -f assert_greater_than
export -f assert_less_than
