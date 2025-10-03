#!/bin/bash
# Parallel Gateway Testing Implementation
# Executes gateway latency tests concurrently to reduce total testing time

# Test gateway latency in parallel using background jobs
# Usage: test_gateways_parallel <interface1:gateway1> <interface2:gateway2> ...
# Returns: Associative array of results via PARALLEL_RESULTS

declare -A PARALLEL_RESULTS
declare -A PARALLEL_PIDS
PARALLEL_TIMEOUT=5  # Maximum time to wait for all tests

test_gateway_parallel() {
    local iface=$1
    local gateway=$2
    local result_file=$3

    # Fast ping with reduced count (3 -> 2) and timeout (1s -> 0.5s)
    local result=$(ping -c 2 -W 1 -i 0.2 -I "$iface" "$gateway" 2>/dev/null | \
                   grep "rtt min/avg/max" | awk -F'/' '{print $5}')

    if [ -z "$result" ]; then
        echo "FAILED" > "$result_file"
        return 1
    fi

    # Return average latency in ms (rounded)
    echo "${result%.*}" > "$result_file"
    return 0
}

test_gateways_parallel_batch() {
    local temp_dir=$(mktemp -d)
    local start_time=$(date +%s.%N)

    # Clear previous results
    PARALLEL_RESULTS=()
    PARALLEL_PIDS=()

    # Launch all tests in parallel
    local iface gateway
    for arg in "$@"; do
        IFS=':' read -r iface gateway <<< "$arg"
        local result_file="$temp_dir/${iface}.result"

        # Launch background job
        test_gateway_parallel "$iface" "$gateway" "$result_file" &
        PARALLEL_PIDS["$iface"]=$!
    done

    # Wait for all background jobs with timeout
    local wait_start=$(date +%s)
    for iface in "${!PARALLEL_PIDS[@]}"; do
        local pid=${PARALLEL_PIDS[$iface]}
        local elapsed=$(($(date +%s) - wait_start))

        if [ $elapsed -ge $PARALLEL_TIMEOUT ]; then
            # Timeout reached, kill remaining processes
            kill -9 $pid 2>/dev/null
            PARALLEL_RESULTS["$iface"]="TIMEOUT"
        else
            # Wait for process with remaining time
            local remaining=$((PARALLEL_TIMEOUT - elapsed))
            if timeout $remaining wait $pid 2>/dev/null; then
                # Read result from file
                local result_file="$temp_dir/${iface}.result"
                if [ -f "$result_file" ]; then
                    PARALLEL_RESULTS["$iface"]=$(cat "$result_file")
                else
                    PARALLEL_RESULTS["$iface"]="FAILED"
                fi
            else
                kill -9 $pid 2>/dev/null
                PARALLEL_RESULTS["$iface"]="TIMEOUT"
            fi
        fi
    done

    # Calculate total execution time
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)

    # Cleanup
    rm -rf "$temp_dir"

    # Export duration for benchmarking
    echo "$duration"
}

# Advanced parallel testing with job control
# Limits concurrent jobs to avoid overwhelming the system
test_gateways_parallel_controlled() {
    local max_concurrent=${1:-4}
    shift

    local temp_dir=$(mktemp -d)
    local start_time=$(date +%s.%N)
    local job_count=0

    PARALLEL_RESULTS=()

    for arg in "$@"; do
        IFS=':' read -r iface gateway <<< "$arg"
        local result_file="$temp_dir/${iface}.result"

        # Launch background job
        test_gateway_parallel "$iface" "$gateway" "$result_file" &
        PARALLEL_PIDS["$iface"]=$!
        job_count=$((job_count + 1))

        # Wait if we've reached max concurrent jobs
        if [ $job_count -ge $max_concurrent ]; then
            # Wait for any job to complete
            wait -n 2>/dev/null
            job_count=$((job_count - 1))
        fi
    done

    # Wait for remaining jobs
    wait

    # Collect results
    for iface in "${!PARALLEL_PIDS[@]}"; do
        local result_file="$temp_dir/${iface}.result"
        if [ -f "$result_file" ]; then
            PARALLEL_RESULTS["$iface"]=$(cat "$result_file")
        else
            PARALLEL_RESULTS["$iface"]="FAILED"
        fi
    done

    # Calculate total execution time
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)

    # Cleanup
    rm -rf "$temp_dir"

    echo "$duration"
}

# Export functions for use in other scripts
export -f test_gateway_parallel
export -f test_gateways_parallel_batch
export -f test_gateways_parallel_controlled
