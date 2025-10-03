#!/bin/bash

#########################################
# Network Stability Testing Module
# Jitter, Packet Loss, MTU Discovery
#########################################

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/logging.sh" 2>/dev/null || true

#########################################
# Jitter Testing Functions
#########################################

# Measure network jitter (latency variation)
# Args: $1 = target IP/hostname, $2 = packet count (default 20)
# Returns: jitter in ms
measure_jitter() {
    local target="$1"
    local count="${2:-20}"
    local ping_output
    local latencies=()
    local avg_jitter=0

    log_info "Measuring jitter to ${target} with ${count} packets..."

    # Collect ping latencies
    ping_output=$(ping -c "$count" -i 0.2 "$target" 2>/dev/null)

    if [ $? -ne 0 ]; then
        log_error "Failed to ping ${target}"
        echo "-1"
        return 1
    fi

    # Extract individual latency values
    while IFS= read -r line; do
        if echo "$line" | grep -q "time="; then
            local latency=$(echo "$line" | grep -oP 'time=\K[\d.]+')
            latencies+=("$latency")
        fi
    done <<< "$ping_output"

    # Calculate jitter (standard deviation of latencies)
    if [ ${#latencies[@]} -lt 2 ]; then
        log_warning "Insufficient data for jitter calculation"
        echo "-1"
        return 1
    fi

    # Calculate mean
    local sum=0
    for lat in "${latencies[@]}"; do
        sum=$(echo "scale=3; ${sum} + ${lat}" | bc -l)
    done
    local mean=$(echo "scale=3; ${sum} / ${#latencies[@]}" | bc -l)

    # Calculate variance
    local variance_sum=0
    for lat in "${latencies[@]}"; do
        local diff=$(echo "scale=3; ${lat} - ${mean}" | bc -l)
        local squared=$(echo "scale=3; ${diff} * ${diff}" | bc -l)
        variance_sum=$(echo "scale=3; ${variance_sum} + ${squared}" | bc -l)
    done
    local variance=$(echo "scale=3; ${variance_sum} / ${#latencies[@]}" | bc -l)

    # Calculate standard deviation (jitter)
    avg_jitter=$(echo "scale=3; sqrt(${variance})" | bc -l)

    log_info "Jitter to ${target}: ${avg_jitter}ms (mean latency: ${mean}ms)"
    echo "$avg_jitter"
    return 0
}

# Comprehensive jitter analysis
# Args: $1 = target, $2 = packet count
# Returns: JSON with jitter statistics
analyze_jitter() {
    local target="$1"
    local count="${2:-30}"
    local latencies=()
    local min_lat=999999
    local max_lat=0

    log_info "Performing comprehensive jitter analysis for ${target}..."

    # Collect detailed ping data
    local ping_output=$(ping -c "$count" -i 0.2 "$target" 2>/dev/null)

    if [ $? -ne 0 ]; then
        echo '{"error": "target_unreachable"}'
        return 1
    fi

    # Parse latency values
    while IFS= read -r line; do
        if echo "$line" | grep -q "time="; then
            local lat=$(echo "$line" | grep -oP 'time=\K[\d.]+')
            latencies+=("$lat")

            # Track min/max
            if (( $(echo "$lat < $min_lat" | bc -l) )); then
                min_lat="$lat"
            fi
            if (( $(echo "$lat > $max_lat" | bc -l) )); then
                max_lat="$lat"
            fi
        fi
    done <<< "$ping_output"

    if [ ${#latencies[@]} -lt 2 ]; then
        echo '{"error": "insufficient_data"}'
        return 1
    fi

    # Calculate statistics
    local sum=0
    for lat in "${latencies[@]}"; do
        sum=$(echo "scale=3; ${sum} + ${lat}" | bc -l)
    done
    local mean=$(echo "scale=3; ${sum} / ${#latencies[@]}" | bc -l)

    # Calculate standard deviation (jitter)
    local variance_sum=0
    for lat in "${latencies[@]}"; do
        local diff=$(echo "scale=3; ${lat} - ${mean}" | bc -l)
        local squared=$(echo "scale=3; ${diff} * ${diff}" | bc -l)
        variance_sum=$(echo "scale=3; ${variance_sum} + ${squared}" | bc -l)
    done
    local variance=$(echo "scale=3; ${variance_sum} / ${#latencies[@]}" | bc -l)
    local jitter=$(echo "scale=3; sqrt(${variance})" | bc -l)

    # Calculate latency range
    local range=$(echo "scale=3; ${max_lat} - ${min_lat}" | bc -l)

    # Jitter quality score (0-100, higher is better)
    # Score based on jitter relative to mean latency
    local jitter_ratio=$(echo "scale=3; ${jitter} / ${mean} * 100" | bc -l)
    local quality_score=100
    if (( $(echo "$jitter_ratio > 50" | bc -l) )); then
        quality_score=0
    elif (( $(echo "$jitter_ratio > 20" | bc -l) )); then
        quality_score=50
    elif (( $(echo "$jitter_ratio > 10" | bc -l) )); then
        quality_score=70
    elif (( $(echo "$jitter_ratio > 5" | bc -l) )); then
        quality_score=85
    fi

    # Output JSON
    cat <<EOF
{
  "target": "${target}",
  "samples": ${#latencies[@]},
  "mean_latency": ${mean},
  "min_latency": ${min_lat},
  "max_latency": ${max_lat},
  "jitter": ${jitter},
  "range": ${range},
  "jitter_ratio": ${jitter_ratio},
  "quality_score": ${quality_score}
}
EOF
}

#########################################
# Packet Loss Testing Functions
#########################################

# Measure packet loss percentage
# Args: $1 = target, $2 = packet count (default 50)
# Returns: packet loss percentage
measure_packet_loss() {
    local target="$1"
    local count="${2:-50}"
    local loss_pct=100

    log_info "Measuring packet loss to ${target} with ${count} packets..."

    # Perform ping test
    local ping_output=$(ping -c "$count" -W 2 "$target" 2>/dev/null)

    if [ $? -eq 0 ]; then
        # Extract packet loss percentage
        loss_pct=$(echo "$ping_output" | grep -oP '\d+(?=% packet loss)' | head -1)

        if [ -z "$loss_pct" ]; then
            loss_pct=100
        fi
    fi

    log_info "Packet loss to ${target}: ${loss_pct}%"
    echo "$loss_pct"
    return 0
}

# Extended packet loss test with burst analysis
# Args: $1 = target, $2 = duration_seconds (default 30)
# Returns: JSON with loss statistics
analyze_packet_loss() {
    local target="$1"
    local duration="${2:-30}"
    local interval=0.5
    local total_sent=0
    local total_received=0
    local consecutive_loss=0
    local max_consecutive_loss=0
    local burst_count=0

    log_info "Performing extended packet loss analysis for ${target} (${duration}s)..."

    local count=$(echo "${duration} / ${interval}" | bc)

    # Run extended ping test
    local ping_output=$(ping -c "$count" -i "$interval" -W 2 "$target" 2>/dev/null)

    # Parse results line by line
    while IFS= read -r line; do
        if echo "$line" | grep -q "bytes from"; then
            # Packet received
            ((total_received++))
            if [ $consecutive_loss -gt 0 ]; then
                if [ $consecutive_loss -gt $max_consecutive_loss ]; then
                    max_consecutive_loss=$consecutive_loss
                fi
                ((burst_count++))
            fi
            consecutive_loss=0
        elif echo "$line" | grep -qE "(timeout|unreachable|no answer)"; then
            # Packet lost
            ((consecutive_loss++))
        fi
    done <<< "$ping_output"

    # Extract total sent and loss percentage from summary
    total_sent=$(echo "$ping_output" | grep -oP '^\d+(?= packets transmitted)' | tail -1)
    local loss_pct=$(echo "$ping_output" | grep -oP '\d+(?=% packet loss)' | tail -1)

    # Defaults if parsing failed
    total_sent=${total_sent:-$count}
    loss_pct=${loss_pct:-100}
    total_received=$((total_sent * (100 - loss_pct) / 100))

    # Loss quality score (0-100)
    local quality_score=0
    if (( loss_pct == 0 )); then
        quality_score=100
    elif (( loss_pct < 1 )); then
        quality_score=90
    elif (( loss_pct < 3 )); then
        quality_score=70
    elif (( loss_pct < 10 )); then
        quality_score=40
    elif (( loss_pct < 25 )); then
        quality_score=20
    fi

    # Output JSON
    cat <<EOF
{
  "target": "${target}",
  "duration_seconds": ${duration},
  "packets_sent": ${total_sent},
  "packets_received": ${total_received},
  "loss_percentage": ${loss_pct},
  "max_consecutive_loss": ${max_consecutive_loss},
  "burst_count": ${burst_count},
  "quality_score": ${quality_score}
}
EOF
}

#########################################
# MTU Discovery Functions
#########################################

# Discover optimal MTU for path to target
# Args: $1 = target, $2 = interface (optional)
# Returns: optimal MTU size
discover_mtu() {
    local target="$1"
    local interface="$2"
    local mtu_min=576
    local mtu_max=1500
    local optimal_mtu=1500

    log_info "Discovering optimal MTU for ${target}..."

    # Binary search for maximum MTU
    local low=$mtu_min
    local high=$mtu_max

    while [ $low -le $high ]; do
        local mid=$(( (low + high) / 2 ))

        # Try to ping with specific packet size (MTU - 28 bytes for IP/ICMP headers)
        local packet_size=$((mid - 28))

        local ping_cmd="ping -c 3 -M do -s $packet_size -W 2"
        [ -n "$interface" ] && ping_cmd="$ping_cmd -I $interface"
        ping_cmd="$ping_cmd $target"

        if $ping_cmd &>/dev/null; then
            # Success - try larger
            optimal_mtu=$mid
            low=$((mid + 8))
        else
            # Failed - try smaller
            high=$((mid - 8))
        fi
    done

    log_info "Optimal MTU for ${target}: ${optimal_mtu}"
    echo "$optimal_mtu"
    return 0
}

# Comprehensive MTU analysis
# Args: $1 = target
# Returns: JSON with MTU information
analyze_mtu() {
    local target="$1"
    local optimal_mtu
    local supports_jumbo=0
    local min_working_mtu=576
    local fragmentation_needed=0

    log_info "Performing comprehensive MTU analysis for ${target}..."

    # Test standard MTU sizes
    local test_sizes=(1500 1492 1480 1460 1400 9000)
    local working_sizes=()

    for size in "${test_sizes[@]}"; do
        local packet_size=$((size - 28))

        if ping -c 2 -M do -s "$packet_size" -W 2 "$target" &>/dev/null; then
            working_sizes+=("$size")
            log_debug "MTU ${size} works for ${target}"

            if [ $size -gt 1500 ]; then
                supports_jumbo=1
            fi
        else
            log_debug "MTU ${size} fails for ${target}"
        fi
    done

    # Find optimal MTU
    if [ ${#working_sizes[@]} -gt 0 ]; then
        # Sort and get maximum working size
        IFS=$'\n' sorted=($(sort -rn <<<"${working_sizes[*]}"))
        optimal_mtu="${sorted[0]}"
        min_working_mtu="${sorted[-1]}"
    else
        optimal_mtu=576
        min_working_mtu=576
        fragmentation_needed=1
    fi

    # Calculate efficiency (how close to 1500 standard MTU)
    local efficiency=$(echo "scale=2; ${optimal_mtu} / 1500 * 100" | bc -l)

    # MTU quality score
    local quality_score=100
    if [ $optimal_mtu -lt 1400 ]; then
        quality_score=60
    elif [ $optimal_mtu -lt 1460 ]; then
        quality_score=80
    elif [ $optimal_mtu -ge 1500 ]; then
        quality_score=100
    fi

    # Output JSON
    cat <<EOF
{
  "target": "${target}",
  "optimal_mtu": ${optimal_mtu},
  "min_working_mtu": ${min_working_mtu},
  "supports_jumbo": ${supports_jumbo},
  "fragmentation_needed": ${fragmentation_needed},
  "efficiency": ${efficiency},
  "quality_score": ${quality_score}
}
EOF
}

#########################################
# Combined Stability Testing
#########################################

# Comprehensive stability test combining all metrics
# Args: $1 = target
# Returns: JSON with all stability metrics
test_network_stability() {
    local target="$1"

    log_info "Running comprehensive stability test for ${target}..."

    # Run all tests
    local jitter_data=$(analyze_jitter "$target" 30)
    local loss_data=$(analyze_packet_loss "$target" 20)
    local mtu_data=$(analyze_mtu "$target")

    # Extract quality scores
    local jitter_score=$(echo "$jitter_data" | grep -oP '"quality_score":\s*\K\d+' || echo "0")
    local loss_score=$(echo "$loss_data" | grep -oP '"quality_score":\s*\K\d+' || echo "0")
    local mtu_score=$(echo "$mtu_data" | grep -oP '"quality_score":\s*\K\d+' || echo "0")

    # Calculate overall stability score (weighted average)
    local stability_score=$(echo "scale=2; (${jitter_score} * 0.35 + ${loss_score} * 0.45 + ${mtu_score} * 0.20)" | bc -l)

    # Determine stability grade
    local grade="F"
    if (( $(echo "$stability_score >= 90" | bc -l) )); then
        grade="A"
    elif (( $(echo "$stability_score >= 80" | bc -l) )); then
        grade="B"
    elif (( $(echo "$stability_score >= 70" | bc -l) )); then
        grade="C"
    elif (( $(echo "$stability_score >= 60" | bc -l) )); then
        grade="D"
    fi

    # Output combined JSON
    cat <<EOF
{
  "target": "${target}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "jitter": ${jitter_data},
  "packet_loss": ${loss_data},
  "mtu": ${mtu_data},
  "overall_stability_score": ${stability_score},
  "grade": "${grade}"
}
EOF
}

# Export functions
export -f measure_jitter
export -f analyze_jitter
export -f measure_packet_loss
export -f analyze_packet_loss
export -f discover_mtu
export -f analyze_mtu
export -f test_network_stability
