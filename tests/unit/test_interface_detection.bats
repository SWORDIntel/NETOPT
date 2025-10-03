#!/usr/bin/env bats
# Unit tests for interface detection functionality

# Load the main script functions
load '../test_helper'

setup() {
    # Source the main script to test its functions
    source "${NETOPT_ROOT}/network-optimize.sh"

    # Create temporary test directory
    export TEST_DIR=$(mktemp -d)
    export CONFIG_DIR="$TEST_DIR/config"
    export LOG_FILE="$TEST_DIR/test.log"
    mkdir -p "$CONFIG_DIR"
}

teardown() {
    # Cleanup temporary directory
    rm -rf "$TEST_DIR"
}

@test "detect_interface_type: ethernet interface with 'en' prefix" {
    result=$(detect_interface_type "enp0s3")
    [ "$result" = "ethernet" ]
}

@test "detect_interface_type: ethernet interface with 'eth' prefix" {
    result=$(detect_interface_type "eth0")
    [ "$result" = "ethernet" ]
}

@test "detect_interface_type: ethernet interface with 'eth' prefix returns correct priority" {
    detect_interface_type "eth0"
    priority=$?
    [ "$priority" -eq 10 ]
}

@test "detect_interface_type: wifi interface with 'wl' prefix" {
    result=$(detect_interface_type "wlp2s0")
    [ "$result" = "wifi" ]
}

@test "detect_interface_type: wifi interface with 'wlan' prefix" {
    result=$(detect_interface_type "wlan0")
    [ "$result" = "wifi" ]
}

@test "detect_interface_type: wifi interface returns correct priority" {
    detect_interface_type "wlan0"
    priority=$?
    [ "$priority" -eq 20 ]
}

@test "detect_interface_type: mobile interface with 'ppp' prefix" {
    result=$(detect_interface_type "ppp0")
    [ "$result" = "mobile" ]
}

@test "detect_interface_type: mobile interface with 'wwan' prefix" {
    result=$(detect_interface_type "wwan0")
    [ "$result" = "mobile" ]
}

@test "detect_interface_type: mobile interface with 'usb' prefix" {
    result=$(detect_interface_type "usb0")
    [ "$result" = "mobile" ]
}

@test "detect_interface_type: mobile interface returns correct priority" {
    detect_interface_type "ppp0"
    priority=$?
    [ "$priority" -eq 30 ]
}

@test "detect_interface_type: unknown interface type" {
    result=$(detect_interface_type "unknown123")
    [ "$result" = "unknown" ]
}

@test "detect_interface_type: unknown interface returns correct priority" {
    detect_interface_type "unknown123"
    priority=$?
    [ "$priority" -eq 40 ]
}

@test "detect_interface_type: docker interface should be recognized" {
    result=$(detect_interface_type "docker0")
    [ "$result" = "unknown" ]
}

@test "detect_interface_type: veth interface" {
    result=$(detect_interface_type "veth123abc")
    [ "$result" = "unknown" ]
}

@test "detect_interface_type: bridge interface" {
    result=$(detect_interface_type "br-123456")
    [ "$result" = "unknown" ]
}

@test "detect_interface_type: empty interface name" {
    result=$(detect_interface_type "")
    [ "$result" = "unknown" ]
}

@test "detect_interface_type: ethernet interface with uppercase" {
    result=$(detect_interface_type "ETH0")
    [ "$result" = "unknown" ]
}

@test "detect_interface_type: complex ethernet interface name" {
    result=$(detect_interface_type "enp3s0f1")
    [ "$result" = "ethernet" ]
}

@test "detect_interface_type: modern wifi interface name" {
    result=$(detect_interface_type "wlp4s0")
    [ "$result" = "wifi" ]
}

@test "detect_interface_type: multiple interface types priority order" {
    detect_interface_type "eth0"
    eth_priority=$?
    detect_interface_type "wlan0"
    wlan_priority=$?
    detect_interface_type "ppp0"
    ppp_priority=$?

    # Ethernet should have highest priority (lowest number)
    [ "$eth_priority" -lt "$wlan_priority" ]
    [ "$wlan_priority" -lt "$ppp_priority" ]
}
