#!/bin/bash
# Performance Benchmark Suite for NETOPT
# Measures execution time, resource usage, and scalability

set -e

# Configuration
BENCHMARK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETOPT_ROOT="${BENCHMARK_DIR}/../.."
RESULTS_DIR="${BENCHMARK_DIR}/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="${RESULTS_DIR}/benchmark_${TIMESTAMP}.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create results directory
mkdir -p "$RESULTS_DIR"

# Logging functions
log() {
    echo -e "${GREEN}[BENCHMARK]${NC} $1" | tee -a "$RESULTS_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$RESULTS_FILE" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$RESULTS_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$RESULTS_FILE"
}

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        warn "Some benchmarks require root privileges for full testing"
        return 1
    fi
    return 0
}

# Measure execution time
measure_time() {
    local cmd=$1
    local description=$2

    info "Testing: $description"

    local start=$(date +%s.%N)
    eval "$cmd" >/dev/null 2>&1
    local end=$(date +%s.%N)

    local duration=$(echo "$end - $start" | bc)
    echo "  Time: ${duration}s" | tee -a "$RESULTS_FILE"
    echo "$duration"
}

# Measure memory usage
measure_memory() {
    local cmd=$1
    local description=$2

    info "Memory test: $description"

    # Start monitoring
    local pid_file=$(mktemp)
    eval "$cmd & echo \$! > $pid_file" >/dev/null 2>&1
    local pid=$(cat "$pid_file")

    # Wait a moment for process to stabilize
    sleep 0.5

    if ps -p "$pid" > /dev/null 2>&1; then
        local mem=$(ps -o rss= -p "$pid" 2>/dev/null || echo "0")
        local mem_mb=$(echo "scale=2; $mem / 1024" | bc)
        echo "  Memory: ${mem_mb}MB" | tee -a "$RESULTS_FILE"
        kill "$pid" 2>/dev/null || true
    else
        echo "  Memory: Process completed too quickly" | tee -a "$RESULTS_FILE"
    fi

    rm -f "$pid_file"
}

# Benchmark: Function execution speed
benchmark_functions() {
    log "Benchmarking function execution speed"

    source "${NETOPT_ROOT}/network-optimize.sh"

    # Test detect_interface_type
    local total=0
    for i in {1..1000}; do
        local start=$(date +%s.%N)
        detect_interface_type "eth0" >/dev/null
        local end=$(date +%s.%N)
        total=$(echo "$total + ($end - $start)" | bc)
    done
    local avg=$(echo "scale=6; $total / 1000" | bc)
    echo "  detect_interface_type: ${avg}s (avg over 1000 calls)" | tee -a "$RESULTS_FILE"

    # Test calculate_weight
    total=0
    for i in {1..1000}; do
        local start=$(date +%s.%N)
        calculate_weight 50 10 >/dev/null
        local end=$(date +%s.%N)
        total=$(echo "$total + ($end - $start)" | bc)
    done
    avg=$(echo "scale=6; $total / 1000" | bc)
    echo "  calculate_weight: ${avg}s (avg over 1000 calls)" | tee -a "$RESULTS_FILE"
}

# Benchmark: Interface detection with varying numbers
benchmark_interface_scaling() {
    log "Benchmarking interface detection scalability"

    # Test with different numbers of interfaces
    for count in 1 5 10 20 50; do
        info "Testing with $count interfaces"

        # Create mock interface list
        local iface_list=""
        for i in $(seq 1 $count); do
            iface_list="${iface_list}eth${i} "
        done

        # Measure time to process all interfaces
        local start=$(date +%s.%N)
        for iface in $iface_list; do
            source "${NETOPT_ROOT}/network-optimize.sh"
            detect_interface_type "$iface" >/dev/null
        done
        local end=$(date +%s.%N)

        local duration=$(echo "$end - $start" | bc)
        echo "  ${count} interfaces: ${duration}s" | tee -a "$RESULTS_FILE"
    done
}

# Benchmark: Weight calculation performance
benchmark_weight_calculation() {
    log "Benchmarking weight calculation with various inputs"

    source "${NETOPT_ROOT}/network-optimize.sh"

    local latencies=(1 5 10 20 50 100 150 200 250)
    local priorities=(10 20 30 40)

    local total_time=0
    local count=0

    for latency in "${latencies[@]}"; do
        for priority in "${priorities[@]}"; do
            local start=$(date +%s.%N)
            for i in {1..100}; do
                calculate_weight "$latency" "$priority" >/dev/null
            done
            local end=$(date +%s.%N)
            local duration=$(echo "$end - $start" | bc)
            total_time=$(echo "$total_time + $duration" | bc)
            count=$((count + 100))
        done
    done

    local avg=$(echo "scale=6; $total_time / $count" | bc)
    echo "  Average calculation time: ${avg}s (over $count calls)" | tee -a "$RESULTS_FILE"
}

# Benchmark: Script startup time
benchmark_script_startup() {
    log "Benchmarking script startup time"

    # Test --help flag (minimal execution)
    local times=()
    for i in {1..10}; do
        local start=$(date +%s.%N)
        bash "${NETOPT_ROOT}/network-optimize.sh" --help >/dev/null 2>&1
        local end=$(date +%s.%N)
        local duration=$(echo "$end - $start" | bc)
        times+=($duration)
    done

    # Calculate average
    local total=0
    for time in "${times[@]}"; do
        total=$(echo "$total + $time" | bc)
    done
    local avg=$(echo "scale=6; $total / 10" | bc)
    echo "  Average startup time: ${avg}s (over 10 runs)" | tee -a "$RESULTS_FILE"
}

# Benchmark: Route backup/restore
benchmark_route_operations() {
    log "Benchmarking route backup and restore operations"

    if ! check_root; then
        warn "Skipping route operations (requires root)"
        return
    fi

    source "${NETOPT_ROOT}/network-optimize.sh"
    export CONFIG_DIR=$(mktemp -d)
    export BACKUP_FILE="$CONFIG_DIR/route-backup.conf"
    export LOG_FILE="$CONFIG_DIR/test.log"

    # Benchmark backup
    local start=$(date +%s.%N)
    backup_routes >/dev/null 2>&1
    local end=$(date +%s.%N)
    local backup_time=$(echo "$end - $start" | bc)
    echo "  Route backup time: ${backup_time}s" | tee -a "$RESULTS_FILE"

    # Benchmark restore
    start=$(date +%s.%N)
    restore_routes >/dev/null 2>&1 || true
    end=$(date +%s.%N)
    local restore_time=$(echo "$end - $start" | bc)
    echo "  Route restore time: ${restore_time}s" | tee -a "$RESULTS_FILE"

    # Cleanup
    rm -rf "$CONFIG_DIR"
}

# Benchmark: Ping latency testing
benchmark_ping_performance() {
    log "Benchmarking ping latency testing"

    # Test ping to localhost (should be very fast)
    local times=()
    for i in {1..5}; do
        local start=$(date +%s.%N)
        ping -c 3 -W 1 127.0.0.1 >/dev/null 2>&1 || true
        local end=$(date +%s.%N)
        local duration=$(echo "$end - $start" | bc)
        times+=($duration)
    done

    # Calculate average
    local total=0
    for time in "${times[@]}"; do
        total=$(echo "$total + $time" | bc)
    done
    local avg=$(echo "scale=3; $total / 5" | bc)
    echo "  Average ping test time: ${avg}s (3 pings to localhost, over 5 runs)" | tee -a "$RESULTS_FILE"
}

# Benchmark: CPU usage during operation
benchmark_cpu_usage() {
    log "Benchmarking CPU usage"

    source "${NETOPT_ROOT}/network-optimize.sh"

    # Run CPU-intensive operations
    local pid_file=$(mktemp)
    (
        for i in {1..1000}; do
            detect_interface_type "eth${i}" >/dev/null
            calculate_weight $((RANDOM % 200)) 10 >/dev/null
        done
    ) & echo $! > "$pid_file"

    local pid=$(cat "$pid_file")
    sleep 0.5

    if ps -p "$pid" > /dev/null 2>&1; then
        local cpu=$(ps -o %cpu= -p "$pid" 2>/dev/null || echo "0")
        echo "  CPU usage during intensive ops: ${cpu}%" | tee -a "$RESULTS_FILE"
        kill "$pid" 2>/dev/null || true
    else
        echo "  CPU: Process completed too quickly" | tee -a "$RESULTS_FILE"
    fi

    rm -f "$pid_file"
}

# Generate performance report
generate_report() {
    log "Generating performance report"

    cat >> "$RESULTS_FILE" <<EOF

================================================================================
PERFORMANCE BENCHMARK SUMMARY
================================================================================
Date: $(date)
Hostname: $(hostname)
Kernel: $(uname -r)
CPU: $(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
Memory: $(free -h | grep "Mem:" | awk '{print $2}')
================================================================================

EOF

    echo "Report saved to: $RESULTS_FILE"
}

# Run all benchmarks
run_all_benchmarks() {
    log "Starting NETOPT Performance Benchmark Suite"
    log "Results will be saved to: $RESULTS_FILE"
    echo ""

    generate_report

    benchmark_script_startup
    echo ""

    benchmark_functions
    echo ""

    benchmark_interface_scaling
    echo ""

    benchmark_weight_calculation
    echo ""

    benchmark_ping_performance
    echo ""

    benchmark_cpu_usage
    echo ""

    if check_root; then
        benchmark_route_operations
        echo ""
    fi

    log "Benchmark suite completed!"
    log "Full results: $RESULTS_FILE"
}

# Compare with previous results
compare_results() {
    local previous=$1

    if [ ! -f "$previous" ]; then
        error "Previous results file not found: $previous"
        return 1
    fi

    log "Comparing with previous results: $previous"
    echo "Current results: $RESULTS_FILE"
    echo ""

    # This is a simple diff - could be enhanced with more sophisticated analysis
    diff -u "$previous" "$RESULTS_FILE" || true
}

# Main script
case "${1:-}" in
    all)
        run_all_benchmarks
        ;;
    functions)
        benchmark_functions
        ;;
    scaling)
        benchmark_interface_scaling
        ;;
    weight)
        benchmark_weight_calculation
        ;;
    startup)
        benchmark_script_startup
        ;;
    routes)
        benchmark_route_operations
        ;;
    ping)
        benchmark_ping_performance
        ;;
    cpu)
        benchmark_cpu_usage
        ;;
    compare)
        if [ -z "$2" ]; then
            error "Usage: $0 compare <previous_results_file>"
            exit 1
        fi
        compare_results "$2"
        ;;
    *)
        echo "NETOPT Performance Benchmark Suite"
        echo ""
        echo "Usage: $0 {all|functions|scaling|weight|startup|routes|ping|cpu|compare}"
        echo ""
        echo "Commands:"
        echo "  all        - Run all benchmarks"
        echo "  functions  - Benchmark core functions"
        echo "  scaling    - Test interface detection scalability"
        echo "  weight     - Benchmark weight calculations"
        echo "  startup    - Measure script startup time"
        echo "  routes     - Benchmark route operations (requires root)"
        echo "  ping       - Test ping performance"
        echo "  cpu        - Measure CPU usage"
        echo "  compare    - Compare with previous results"
        echo ""
        echo "Examples:"
        echo "  $0 all                                    # Run all benchmarks"
        echo "  $0 compare results/benchmark_<date>.txt   # Compare results"
        exit 1
        ;;
esac
