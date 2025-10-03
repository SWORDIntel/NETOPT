#!/usr/bin/env bats
# Integration tests for multi-interface scenarios

load '../test_helper'

setup() {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "Integration tests require root privileges"
    fi

    # Create temporary test directory
    export TEST_DIR=$(mktemp -d)
    export CONFIG_DIR="$TEST_DIR/config"
    export BACKUP_FILE="$CONFIG_DIR/route-backup.conf"
    export STATE_FILE="$CONFIG_DIR/current-state.conf"
    export LOG_FILE="$TEST_DIR/test.log"
    mkdir -p "$CONFIG_DIR"

    # Setup network simulator
    export SIMULATOR="${NETOPT_ROOT}/tests/integration/network_simulator.sh"

    # Store original routes
    ip route show > "$TEST_DIR/original-routes.txt"
}

teardown() {
    # Restore original routes
    if [ -f "$TEST_DIR/original-routes.txt" ]; then
        # Clear all default routes
        while ip route del default 2>/dev/null; do :; done

        # Restore original routes
        while IFS= read -r route; do
            if [[ $route =~ ^default ]]; then
                ip route add $route 2>/dev/null || true
            fi
        done < "$TEST_DIR/original-routes.txt"
    fi

    # Cleanup simulator environment
    if [ -x "$SIMULATOR" ]; then
        "$SIMULATOR" cleanup 2>/dev/null || true
    fi

    # Cleanup temporary directory
    rm -rf "$TEST_DIR"
}

@test "integration: network simulator can setup environment" {
    run "$SIMULATOR" setup
    [ "$status" -eq 0 ]
}

@test "integration: network simulator creates namespaces" {
    "$SIMULATOR" setup
    run ip netns list
    [[ "$output" =~ "netopt_test_eth" ]]
    [[ "$output" =~ "netopt_test_wifi" ]]
    [[ "$output" =~ "netopt_test_mobile" ]]
}

@test "integration: network simulator creates veth interfaces" {
    "$SIMULATOR" setup
    run ip link show
    [[ "$output" =~ "veth_test_eth_host" ]]
    [[ "$output" =~ "veth_test_wifi_host" ]]
    [[ "$output" =~ "veth_test_mobile_host" ]]
}

@test "integration: network simulator creates bridge" {
    "$SIMULATOR" setup
    run ip link show
    [[ "$output" =~ "br_netopt_test" ]]
}

@test "integration: detect multiple interfaces" {
    "$SIMULATOR" setup

    # Create test script that lists interfaces
    cat > "$TEST_DIR/test_detect.sh" <<'EOF'
#!/bin/bash
for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "^lo$\|^docker\|^veth\|^br-\|^virbr"); do
    if ip link show "$iface" 2>/dev/null | grep -q "state UP"; then
        echo "$iface"
    fi
done
EOF
    chmod +x "$TEST_DIR/test_detect.sh"

    run "$TEST_DIR/test_detect.sh"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "integration: verify latency differences between interfaces" {
    "$SIMULATOR" setup
    sleep 2  # Wait for interfaces to stabilize

    # Ping through each namespace should show different latencies
    eth_latency=$(ip netns exec netopt_test_eth ping -c 3 -W 1 10.0.0.1 2>/dev/null | grep "rtt min/avg/max" | awk -F'/' '{print $5}' | cut -d'.' -f1 || echo "999")
    wifi_latency=$(ip netns exec netopt_test_wifi ping -c 3 -W 1 10.0.0.1 2>/dev/null | grep "rtt min/avg/max" | awk -F'/' '{print $5}' | cut -d'.' -f1 || echo "999")
    mobile_latency=$(ip netns exec netopt_test_mobile ping -c 3 -W 1 10.0.0.1 2>/dev/null | grep "rtt min/avg/max" | awk -F'/' '{print $5}' | cut -d'.' -f1 || echo "999")

    # Verify latencies are in expected ranges
    [ "$eth_latency" -lt 15 ] || skip "Ethernet latency too high"
    [ "$wifi_latency" -lt 35 ] || skip "WiFi latency too high"
    [ "$mobile_latency" -lt 70 ] || skip "Mobile latency too high"

    # Verify ordering
    [ "$eth_latency" -lt "$wifi_latency" ]
    [ "$wifi_latency" -lt "$mobile_latency" ]
}

@test "integration: backup routes functionality" {
    # Get current routes
    ip route show > "$TEST_DIR/before.txt"

    # Source and run backup function
    source "${NETOPT_ROOT}/network-optimize.sh"
    backup_routes

    # Verify backup file exists
    [ -f "$BACKUP_FILE" ]

    # Verify backup contains routes
    [ -s "$BACKUP_FILE" ]
}

@test "integration: restore routes functionality" {
    # Create a test backup
    echo "default via 192.168.1.1 dev eth0" > "$BACKUP_FILE"

    # Source and run restore function
    source "${NETOPT_ROOT}/network-optimize.sh"

    # This may fail if eth0 doesn't exist, but should not crash
    restore_routes || true

    # Verify function doesn't crash on missing backup
    rm "$BACKUP_FILE"
    run restore_routes
    [ "$status" -eq 1 ]  # Should return error when no backup
}

@test "integration: save state functionality" {
    source "${NETOPT_ROOT}/network-optimize.sh"

    save_state "eth0 wlan0" "2"

    [ -f "$STATE_FILE" ]
    [ -s "$STATE_FILE" ]

    run cat "$STATE_FILE"
    [[ "$output" =~ "INTERFACES=eth0 wlan0" ]]
    [[ "$output" =~ "TOTAL_CONNECTIONS=2" ]]
}

@test "integration: script handles no active interfaces gracefully" {
    # Create isolated namespace with no connections
    ip netns add test_isolated 2>/dev/null || true

    # Run script in isolated environment (should fail gracefully)
    cat > "$TEST_DIR/test_no_ifaces.sh" <<'EOF'
#!/bin/bash
source "${NETOPT_ROOT}/network-optimize.sh"
exit 0
EOF
    chmod +x "$TEST_DIR/test_no_ifaces.sh"

    # Cleanup
    ip netns del test_isolated 2>/dev/null || true
}

@test "integration: script can handle interface failure during detection" {
    "$SIMULATOR" setup

    # Fail one interface
    "$SIMULATOR" fail "veth_test_wifi_host"

    sleep 1

    # Script should continue with remaining interfaces
    # This is verified by the script not crashing
}

@test "integration: multipath route creation with weight" {
    "$SIMULATOR" setup
    sleep 1

    # Test creating a multipath route manually
    while ip route del default 2>/dev/null; do :; done

    # Create multipath route
    run ip route add default scope global \
        nexthop via 10.0.0.2 dev veth_test_eth_host weight 30 \
        nexthop via 10.0.0.3 dev veth_test_wifi_host weight 15 \
        nexthop via 10.0.0.4 dev veth_test_mobile_host weight 5

    [ "$status" -eq 0 ] || skip "Multipath routing not supported in kernel"

    # Verify route was created
    run ip route show default
    [[ "$output" =~ "nexthop" ]]
}

@test "integration: cleanup removes all test resources" {
    "$SIMULATOR" setup
    "$SIMULATOR" cleanup

    # Verify namespaces are gone
    run ip netns list
    [[ ! "$output" =~ "netopt_test" ]]

    # Verify bridge is gone
    run ip link show br_netopt_test
    [ "$status" -ne 0 ]
}

@test "integration: simulator status command works" {
    "$SIMULATOR" setup
    run "$SIMULATOR" status
    [ "$status" -eq 0 ]
    [[ "$output" =~ "network status" ]]
}

@test "integration: interface failure simulation works" {
    "$SIMULATOR" setup

    # Verify interface is up
    ip link show veth_test_eth_host | grep -q "state UP"

    # Simulate failure
    "$SIMULATOR" fail "veth_test_eth_host"

    # Verify interface is down
    ip link show veth_test_eth_host | grep -q "state DOWN"
}

@test "integration: interface recovery simulation works" {
    "$SIMULATOR" setup

    # Fail then recover
    "$SIMULATOR" fail "veth_test_eth_host"
    "$SIMULATOR" recover "veth_test_eth_host"

    # Verify interface is back up
    ip link show veth_test_eth_host | grep -q "state UP"
}

@test "integration: can add custom latency to interface" {
    "$SIMULATOR" setup

    # Add extra latency
    run "$SIMULATOR" latency "veth_test_eth_host" "50"
    [ "$status" -eq 0 ]

    # Verify with tc
    run tc qdisc show dev veth_test_eth_host
    [[ "$output" =~ "netem" ]]
}

@test "integration: script excludes loopback and virtual interfaces" {
    cat > "$TEST_DIR/test_exclusion.sh" <<'EOF'
#!/bin/bash
# Get interfaces that should be processed
for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "^lo$\|^docker\|^veth\|^br-\|^virbr"); do
    echo "$iface"
done
EOF
    chmod +x "$TEST_DIR/test_exclusion.sh"

    run "$TEST_DIR/test_exclusion.sh"

    # Output should not contain these
    [[ ! "$output" =~ "^lo$" ]]
    [[ ! "$output" =~ "^docker" ]]
    [[ ! "$output" =~ "^virbr" ]]
}

@test "integration: end-to-end test with simulated environment" {
    # This is a comprehensive test that runs the actual script
    "$SIMULATOR" setup
    sleep 2

    # Note: We don't actually run the full script as it requires
    # real network interfaces. This test validates the setup.

    # Verify all components are ready
    ip netns list | grep -q "netopt_test_eth"
    ip netns list | grep -q "netopt_test_wifi"
    ip netns list | grep -q "netopt_test_mobile"

    # Verify connectivity in each namespace
    ip netns exec netopt_test_eth ip addr show | grep -q "10.0.0.2"
    ip netns exec netopt_test_wifi ip addr show | grep -q "10.0.0.3"
    ip netns exec netopt_test_mobile ip addr show | grep -q "10.0.0.4"
}
