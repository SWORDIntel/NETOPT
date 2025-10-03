#!/bin/bash
# Optimized Testing Functions for Fast Gateway Latency Detection
# Reduces ping count, timeout, and interval for faster network testing

# Fast ping with minimal overhead
# Reduces from 3 pings/1s timeout to 2 pings/0.5s timeout
fast_ping() {
    local gateway=$1
    local iface=$2
    local ping_count=${3:-2}       # Default 2 pings (was 3)
    local timeout=${4:-1}          # Default 1 second total timeout (was 3s total)
    local interval=${5:-0.2}       # Default 0.2s interval between pings

    # Execute fast ping
    local result=$(ping -c $ping_count -W $timeout -i $interval -I "$iface" "$gateway" 2>/dev/null | \
                   grep "rtt min/avg/max" | awk -F'/' '{print $5}')

    if [ -z "$result" ]; then
        return 1  # Failed
    fi

    # Return average latency in ms (rounded)
    echo "${result%.*}"
    return 0
}

# Ultra-fast ping for quick connectivity check (single ping)
ultra_fast_ping() {
    local gateway=$1
    local iface=$2

    # Single ping with 500ms timeout
    if ping -c 1 -W 1 -I "$iface" "$gateway" &>/dev/null; then
        return 0  # Reachable
    else
        return 1  # Not reachable
    fi
}

# Adaptive ping: starts with ultra-fast, falls back to fast if needed
adaptive_ping() {
    local gateway=$1
    local iface=$2

    # First, try ultra-fast connectivity check
    if ! ultra_fast_ping "$gateway" "$iface"; then
        return 1  # Gateway not reachable
    fi

    # Gateway is reachable, now measure latency with fast ping
    fast_ping "$gateway" "$iface"
    return $?
}

# Optimized gateway test with early exit
# Exits immediately if gateway doesn't respond to first ping
test_gateway_optimized() {
    local gateway=$1
    local iface=$2

    # Quick connectivity check first (saves time on dead gateways)
    if ! ping -c 1 -W 1 -I "$iface" "$gateway" &>/dev/null; then
        return 1  # Dead gateway, exit early
    fi

    # Gateway alive, measure actual latency
    local result=$(ping -c 2 -W 1 -i 0.2 -I "$iface" "$gateway" 2>/dev/null | \
                   grep "rtt min/avg/max" | awk -F'/' '{print $5}')

    if [ -z "$result" ]; then
        return 1
    fi

    echo "${result%.*}"
    return 0
}

# Batch optimized testing (non-parallel but fast)
test_gateways_optimized_batch() {
    declare -A OPTIMIZED_RESULTS
    local start_time=$(date +%s.%N)

    for arg in "$@"; do
        IFS=':' read -r iface gateway <<< "$arg"

        local latency=$(test_gateway_optimized "$gateway" "$iface")
        if [ $? -eq 0 ]; then
            OPTIMIZED_RESULTS["$iface"]="$latency"
        else
            OPTIMIZED_RESULTS["$iface"]="FAILED"
        fi
    done

    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)

    # Export results
    export OPTIMIZED_RESULTS
    echo "$duration"
}

# Smart ping: Choose strategy based on network conditions
# Uses ultra-fast for initial check, fast for measurement
smart_ping() {
    local gateway=$1
    local iface=$2
    local mode=${3:-"auto"}  # auto, fast, ultra

    case $mode in
        ultra)
            ultra_fast_ping "$gateway" "$iface"
            return $?
            ;;
        fast)
            fast_ping "$gateway" "$iface"
            return $?
            ;;
        auto|*)
            adaptive_ping "$gateway" "$iface"
            return $?
            ;;
    esac
}

# Progressive timeout: Start with short timeout, increase if needed
# Useful for unstable networks
progressive_ping() {
    local gateway=$1
    local iface=$2

    # Try with shortest timeout first (0.5s)
    local result=$(ping -c 1 -W 1 -I "$iface" "$gateway" 2>/dev/null | \
                   grep "time=" | grep -oP 'time=\K[0-9.]+')

    if [ -n "$result" ]; then
        echo "${result%.*}"
        return 0
    fi

    # Retry with longer timeout (1s)
    result=$(ping -c 1 -W 1 -I "$iface" "$gateway" 2>/dev/null | \
             grep "time=" | grep -oP 'time=\K[0-9.]+')

    if [ -n "$result" ]; then
        echo "${result%.*}"
        return 0
    fi

    # Final attempt with full timeout (2s)
    result=$(ping -c 2 -W 1 -i 0.3 -I "$iface" "$gateway" 2>/dev/null | \
             grep "rtt min/avg/max" | awk -F'/' '{print $5}')

    if [ -n "$result" ]; then
        echo "${result%.*}"
        return 0
    fi

    return 1  # All attempts failed
}

# Benchmark different ping strategies
benchmark_ping_strategies() {
    local gateway=$1
    local iface=$2
    local iterations=${3:-5}

    echo "=== Ping Strategy Benchmark ==="
    echo "Gateway: $gateway, Interface: $iface, Iterations: $iterations"
    echo ""

    # Benchmark standard ping
    echo -n "Standard ping (3 pings, 1s timeout): "
    local start=$(date +%s.%N)
    for i in $(seq 1 $iterations); do
        ping -c 3 -W 1 -I "$iface" "$gateway" &>/dev/null
    done
    local end=$(date +%s.%N)
    local duration=$(echo "scale=3; ($end - $start) / $iterations" | bc)
    echo "${duration}s per test"

    # Benchmark fast ping
    echo -n "Fast ping (2 pings, 0.2s interval): "
    start=$(date +%s.%N)
    for i in $(seq 1 $iterations); do
        fast_ping "$gateway" "$iface" &>/dev/null
    done
    end=$(date +%s.%N)
    duration=$(echo "scale=3; ($end - $start) / $iterations" | bc)
    echo "${duration}s per test"

    # Benchmark ultra-fast ping
    echo -n "Ultra-fast ping (1 ping): "
    start=$(date +%s.%N)
    for i in $(seq 1 $iterations); do
        ultra_fast_ping "$gateway" "$iface" &>/dev/null
    done
    end=$(date +%s.%N)
    duration=$(echo "scale=3; ($end - $start) / $iterations" | bc)
    echo "${duration}s per test"

    # Benchmark optimized test
    echo -n "Optimized test (early exit): "
    start=$(date +%s.%N)
    for i in $(seq 1 $iterations); do
        test_gateway_optimized "$gateway" "$iface" &>/dev/null
    done
    end=$(date +%s.%N)
    duration=$(echo "scale=3; ($end - $start) / $iterations" | bc)
    echo "${duration}s per test"
}

# Export functions for use in other scripts
export -f fast_ping
export -f ultra_fast_ping
export -f adaptive_ping
export -f test_gateway_optimized
export -f test_gateways_optimized_batch
export -f smart_ping
export -f progressive_ping
export -f benchmark_ping_strategies
