#!/usr/bin/env bats
# Unit tests for weight calculation functionality

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

    # Set constants from the script
    export PRIORITY_ETHERNET=10
    export PRIORITY_WIFI=20
    export PRIORITY_MOBILE=30
    export PRIORITY_UNKNOWN=40
    export MAX_LATENCY=200
}

teardown() {
    # Cleanup temporary directory
    rm -rf "$TEST_DIR"
}

@test "calculate_weight: low latency ethernet gets high weight" {
    result=$(calculate_weight 10 $PRIORITY_ETHERNET)
    [ "$result" -ge 30 ]
}

@test "calculate_weight: medium latency ethernet" {
    result=$(calculate_weight 50 $PRIORITY_ETHERNET)
    expected=$(( (200 - 50) / 10 * 2 ))  # (MAX_LATENCY - latency) / 10 * 2
    [ "$result" -eq "$expected" ]
}

@test "calculate_weight: high latency ethernet still gets some weight" {
    result=$(calculate_weight 180 $PRIORITY_ETHERNET)
    [ "$result" -ge 1 ]
}

@test "calculate_weight: low latency wifi" {
    result=$(calculate_weight 10 $PRIORITY_WIFI)
    expected=$(( (200 - 10) / 10 ))  # (MAX_LATENCY - latency) / 10
    # WiFi multiplier is 1x, but capped at 20
    [ "$result" -eq 19 ]
}

@test "calculate_weight: medium latency wifi" {
    result=$(calculate_weight 100 $PRIORITY_WIFI)
    expected=$(( (200 - 100) / 10 ))  # Should be 10
    [ "$result" -eq "$expected" ]
}

@test "calculate_weight: high latency wifi" {
    result=$(calculate_weight 190 $PRIORITY_WIFI)
    expected=$(( (200 - 190) / 10 ))  # Should be 1
    [ "$result" -eq 1 ]
}

@test "calculate_weight: low latency mobile" {
    result=$(calculate_weight 10 $PRIORITY_MOBILE)
    # Mobile gets divided by 2, so (200-10)/10/2 = 9
    [ "$result" -ge 1 ]
}

@test "calculate_weight: medium latency mobile" {
    result=$(calculate_weight 100 $PRIORITY_MOBILE)
    expected=$(( (200 - 100) / 10 / 2 ))  # Should be 5
    [ "$result" -eq "$expected" ]
}

@test "calculate_weight: high latency mobile gets minimum weight" {
    result=$(calculate_weight 190 $PRIORITY_MOBILE)
    [ "$result" -ge 1 ]
}

@test "calculate_weight: latency exceeding MAX_LATENCY gets minimum weight" {
    result=$(calculate_weight 250 $PRIORITY_WIFI)
    [ "$result" -eq 1 ]
}

@test "calculate_weight: zero latency gets maximum weight before cap" {
    result=$(calculate_weight 0 $PRIORITY_WIFI)
    expected=$(( (200 - 0) / 10 ))  # 20, which is the cap
    [ "$result" -eq 20 ]
}

@test "calculate_weight: ethernet has higher weight than wifi at same latency" {
    eth_weight=$(calculate_weight 50 $PRIORITY_ETHERNET)
    wifi_weight=$(calculate_weight 50 $PRIORITY_WIFI)
    [ "$eth_weight" -gt "$wifi_weight" ]
}

@test "calculate_weight: wifi has higher weight than mobile at same latency" {
    wifi_weight=$(calculate_weight 50 $PRIORITY_WIFI)
    mobile_weight=$(calculate_weight 50 $PRIORITY_MOBILE)
    [ "$wifi_weight" -gt "$mobile_weight" ]
}

@test "calculate_weight: ethernet has higher weight than mobile at same latency" {
    eth_weight=$(calculate_weight 50 $PRIORITY_ETHERNET)
    mobile_weight=$(calculate_weight 50 $PRIORITY_MOBILE)
    [ "$eth_weight" -gt "$mobile_weight" ]
}

@test "calculate_weight: weight is always at least 1" {
    result=$(calculate_weight 199 $PRIORITY_MOBILE)
    [ "$result" -ge 1 ]
}

@test "calculate_weight: weight is capped at 20 for wifi" {
    result=$(calculate_weight 0 $PRIORITY_WIFI)
    [ "$result" -le 20 ]
}

@test "calculate_weight: weight is capped at 40 for ethernet (20*2)" {
    result=$(calculate_weight 0 $PRIORITY_ETHERNET)
    [ "$result" -le 40 ]
}

@test "calculate_weight: boundary test at MAX_LATENCY" {
    result=$(calculate_weight 200 $PRIORITY_WIFI)
    [ "$result" -eq 1 ]
}

@test "calculate_weight: latency 1ms below MAX_LATENCY" {
    result=$(calculate_weight 199 $PRIORITY_WIFI)
    [ "$result" -ge 1 ]
}

@test "calculate_weight: realistic ethernet scenario (5ms latency)" {
    result=$(calculate_weight 5 $PRIORITY_ETHERNET)
    # (200-5)/10*2 = 39, capped at 40
    [ "$result" -ge 30 ]
    [ "$result" -le 40 ]
}

@test "calculate_weight: realistic wifi scenario (20ms latency)" {
    result=$(calculate_weight 20 $PRIORITY_WIFI)
    expected=$(( (200 - 20) / 10 ))  # 18
    [ "$result" -eq "$expected" ]
}

@test "calculate_weight: realistic mobile scenario (50ms latency)" {
    result=$(calculate_weight 50 $PRIORITY_MOBILE)
    expected=$(( (200 - 50) / 10 / 2 ))  # 7
    [ "$result" -eq "$expected" ]
}

@test "calculate_weight: negative latency treated as large value" {
    result=$(calculate_weight -10 $PRIORITY_WIFI)
    [ "$result" -eq 1 ]
}

@test "calculate_weight: priority comparison at same low latency" {
    eth=$(calculate_weight 10 $PRIORITY_ETHERNET)
    wifi=$(calculate_weight 10 $PRIORITY_WIFI)
    mobile=$(calculate_weight 10 $PRIORITY_MOBILE)
    unknown=$(calculate_weight 10 $PRIORITY_UNKNOWN)

    # Verify priority order is maintained
    [ "$eth" -gt "$wifi" ]
    [ "$wifi" -gt "$mobile" ]
}
