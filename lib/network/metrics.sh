#!/bin/bash

#########################################
# Network Metrics Module
# Bandwidth Testing and Quality Scoring
#########################################

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/logging.sh" 2>/dev/null || true

#########################################
# Bandwidth Testing Functions
#########################################

# Estimate bandwidth using ping-based method
# Args: $1 = target, $2 = packet_sizes (default: small,medium,large)
# Returns: estimated bandwidth in Mbps
estimate_bandwidth_ping() {
    local target="$1"
    local test_sizes=(64 512 1472)  # Small, medium, large packets
    local total_throughput=0
    local successful_tests=0

    log_info "Estimating bandwidth to ${target} using ping method..."

    for size in "${test_sizes[@]}"; do
        # Send 10 packets of each size
        local ping_output=$(ping -c 10 -s "$size" -i 0.2 "$target" 2>/dev/null)

        if [ $? -eq 0 ]; then
            # Extract average latency
            local avg_latency=$(echo "$ping_output" | grep -oP 'avg[^/]*/\K[\d.]+' | head -1)

            if [ -n "$avg_latency" ] && [ "$avg_latency" != "0" ]; then
                # Calculate throughput: (packet_size * 8 bits) / (latency / 1000) = bps
                # Add IP/ICMP overhead (28 bytes)
                local total_size=$((size + 28))
                local throughput=$(echo "scale=2; ${total_size} * 8 / (${avg_latency} / 1000)" | bc -l)
                local throughput_mbps=$(echo "scale=2; ${throughput} / 1000000" | bc -l)

                total_throughput=$(echo "scale=2; ${total_throughput} + ${throughput_mbps}" | bc -l)
                ((successful_tests++))

                log_debug "Size ${size}: ${throughput_mbps} Mbps (latency: ${avg_latency}ms)"
            fi
        fi
    done

    if [ $successful_tests -gt 0 ]; then
        local avg_bandwidth=$(echo "scale=2; ${total_throughput} / ${successful_tests}" | bc -l)
        log_info "Estimated bandwidth to ${target}: ${avg_bandwidth} Mbps"
        echo "$avg_bandwidth"
    else
        log_warning "Failed to estimate bandwidth to ${target}"
        echo "-1"
    fi

    return 0
}

# Measure download speed using curl/wget
# Args: $1 = test URL (optional, uses default if not provided)
# Returns: download speed in Mbps
measure_download_speed() {
    local test_url="${1:-http://speedtest.tele2.net/1MB.zip}"
    local speed_mbps=-1

    log_info "Measuring download speed from ${test_url}..."

    if command -v curl &> /dev/null; then
        # Use curl to download and measure speed
        local curl_output=$(curl -s -w '%{speed_download}' -o /dev/null -m 30 "$test_url" 2>/dev/null)

        if [ $? -eq 0 ] && [ -n "$curl_output" ]; then
            # Convert bytes/sec to Mbps
            speed_mbps=$(echo "scale=2; ${curl_output} * 8 / 1000000" | bc -l)
            log_info "Download speed: ${speed_mbps} Mbps"
        fi
    elif command -v wget &> /dev/null; then
        # Fallback to wget
        local wget_output=$(wget -O /dev/null "$test_url" 2>&1 | grep -oP '\([\d.]+ [KM]B/s\)' | tail -1)

        if [ -n "$wget_output" ]; then
            # Parse wget speed output
            local speed_value=$(echo "$wget_output" | grep -oP '[\d.]+')
            local speed_unit=$(echo "$wget_output" | grep -oP '[KM]B')

            if [ "$speed_unit" = "MB" ]; then
                speed_mbps=$(echo "scale=2; ${speed_value} * 8" | bc -l)
            elif [ "$speed_unit" = "KB" ]; then
                speed_mbps=$(echo "scale=2; ${speed_value} * 8 / 1000" | bc -l)
            fi

            log_info "Download speed: ${speed_mbps} Mbps"
        fi
    else
        log_warning "Neither curl nor wget available for bandwidth testing"
    fi

    echo "$speed_mbps"
    return 0
}

# Measure available bandwidth using iperf3
# Args: $1 = iperf3 server address
# Returns: bandwidth in Mbps
measure_bandwidth_iperf() {
    local server="$1"
    local bandwidth=-1

    if ! command -v iperf3 &> /dev/null; then
        log_warning "iperf3 not installed, skipping iperf bandwidth test"
        echo "-1"
        return 1
    fi

    log_info "Measuring bandwidth to ${server} using iperf3..."

    # Run iperf3 test (10 second test)
    local iperf_output=$(iperf3 -c "$server" -t 10 -J 2>/dev/null)

    if [ $? -eq 0 ]; then
        # Parse JSON output for bits_per_second
        bandwidth=$(echo "$iperf_output" | grep -oP '"bits_per_second":\s*\K[\d.]+' | tail -1)

        if [ -n "$bandwidth" ]; then
            # Convert to Mbps
            bandwidth=$(echo "scale=2; ${bandwidth} / 1000000" | bc -l)
            log_info "iperf3 bandwidth: ${bandwidth} Mbps"
        else
            bandwidth=-1
        fi
    else
        log_warning "iperf3 test failed to ${server}"
        bandwidth=-1
    fi

    echo "$bandwidth"
    return 0
}

#########################################
# Network Quality Scoring Functions
#########################################

# Calculate link quality score based on multiple metrics
# Args: $1 = latency_ms, $2 = jitter_ms, $3 = loss_pct, $4 = bandwidth_mbps
# Returns: quality score (0-100)
calculate_link_quality() {
    local latency="$1"
    local jitter="$2"
    local loss="$3"
    local bandwidth="$4"

    # Default values for missing parameters
    latency=${latency:-999}
    jitter=${jitter:-999}
    loss=${loss:-100}
    bandwidth=${bandwidth:-0}

    log_debug "Calculating link quality: latency=${latency}ms, jitter=${jitter}ms, loss=${loss}%, bw=${bandwidth}Mbps"

    # Latency score (0-30 points)
    local latency_score=0
    if (( $(echo "$latency < 10" | bc -l) )); then
        latency_score=30
    elif (( $(echo "$latency < 30" | bc -l) )); then
        latency_score=25
    elif (( $(echo "$latency < 50" | bc -l) )); then
        latency_score=20
    elif (( $(echo "$latency < 100" | bc -l) )); then
        latency_score=15
    elif (( $(echo "$latency < 200" | bc -l) )); then
        latency_score=10
    elif (( $(echo "$latency < 300" | bc -l) )); then
        latency_score=5
    fi

    # Jitter score (0-25 points)
    local jitter_score=0
    local jitter_ratio=100
    if (( $(echo "$latency > 0" | bc -l) )); then
        jitter_ratio=$(echo "scale=2; ${jitter} / ${latency} * 100" | bc -l)
    fi

    if (( $(echo "$jitter_ratio < 5" | bc -l) )); then
        jitter_score=25
    elif (( $(echo "$jitter_ratio < 10" | bc -l) )); then
        jitter_score=20
    elif (( $(echo "$jitter_ratio < 15" | bc -l) )); then
        jitter_score=15
    elif (( $(echo "$jitter_ratio < 25" | bc -l) )); then
        jitter_score=10
    elif (( $(echo "$jitter_ratio < 50" | bc -l) )); then
        jitter_score=5
    fi

    # Packet loss score (0-30 points)
    local loss_score=0
    if (( $(echo "$loss == 0" | bc -l) )); then
        loss_score=30
    elif (( $(echo "$loss < 0.5" | bc -l) )); then
        loss_score=28
    elif (( $(echo "$loss < 1" | bc -l) )); then
        loss_score=25
    elif (( $(echo "$loss < 2" | bc -l) )); then
        loss_score=20
    elif (( $(echo "$loss < 5" | bc -l) )); then
        loss_score=15
    elif (( $(echo "$loss < 10" | bc -l) )); then
        loss_score=10
    elif (( $(echo "$loss < 20" | bc -l) )); then
        loss_score=5
    fi

    # Bandwidth score (0-15 points)
    local bw_score=0
    if (( $(echo "$bandwidth >= 100" | bc -l) )); then
        bw_score=15
    elif (( $(echo "$bandwidth >= 50" | bc -l) )); then
        bw_score=12
    elif (( $(echo "$bandwidth >= 25" | bc -l) )); then
        bw_score=10
    elif (( $(echo "$bandwidth >= 10" | bc -l) )); then
        bw_score=8
    elif (( $(echo "$bandwidth >= 5" | bc -l) )); then
        bw_score=5
    elif (( $(echo "$bandwidth >= 1" | bc -l) )); then
        bw_score=3
    fi

    # Calculate total quality score
    local total_score=$(echo "scale=0; ${latency_score} + ${jitter_score} + ${loss_score} + ${bw_score}" | bc -l)

    # Ensure score is in 0-100 range
    if (( $(echo "$total_score > 100" | bc -l) )); then
        total_score=100
    elif (( $(echo "$total_score < 0" | bc -l) )); then
        total_score=0
    fi

    log_info "Link quality score: ${total_score}/100 (lat:${latency_score}, jit:${jitter_score}, loss:${loss_score}, bw:${bw_score})"
    echo "$total_score"
}

# Generate quality grade from score
# Args: $1 = quality_score (0-100)
# Returns: letter grade (A-F)
get_quality_grade() {
    local score="$1"

    if (( $(echo "$score >= 90" | bc -l) )); then
        echo "A"
    elif (( $(echo "$score >= 80" | bc -l) )); then
        echo "B"
    elif (( $(echo "$score >= 70" | bc -l) )); then
        echo "C"
    elif (( $(echo "$score >= 60" | bc -l) )); then
        echo "D"
    elif (( $(echo "$score >= 50" | bc -l) )); then
        echo "E"
    else
        echo "F"
    fi
}

#########################################
# Composite Quality Scoring
#########################################

# Comprehensive network quality assessment
# Args: $1 = target
# Returns: JSON with complete quality metrics
assess_network_quality() {
    local target="$1"

    log_info "Performing comprehensive network quality assessment for ${target}..."

    # Gather all metrics
    local latency=-1
    local jitter=-1
    local loss=100
    local bandwidth=-1

    # Measure latency
    local ping_output=$(ping -c 10 "$target" 2>/dev/null)
    if [ $? -eq 0 ]; then
        latency=$(echo "$ping_output" | grep -oP 'avg[^/]*/\K[\d.]+' | head -1)
        loss=$(echo "$ping_output" | grep -oP '\d+(?=% packet loss)')
    fi

    # Measure jitter (using stability-testing if available)
    if [ -f "${SCRIPT_DIR}/stability-testing.sh" ]; then
        source "${SCRIPT_DIR}/stability-testing.sh"
        jitter=$(measure_jitter "$target" 20)
    fi

    # Estimate bandwidth
    bandwidth=$(estimate_bandwidth_ping "$target")

    # Calculate quality scores
    local quality_score=$(calculate_link_quality "$latency" "$jitter" "$loss" "$bandwidth")
    local grade=$(get_quality_grade "$quality_score")

    # Determine quality category
    local category="POOR"
    if (( $(echo "$quality_score >= 80" | bc -l) )); then
        category="EXCELLENT"
    elif (( $(echo "$quality_score >= 65" | bc -l) )); then
        category="GOOD"
    elif (( $(echo "$quality_score >= 50" | bc -l) )); then
        category="FAIR"
    fi

    # Calculate MOS score (Mean Opinion Score) approximation for VoIP quality
    # Based on ITU-T G.107 E-model simplified
    local mos=1.0
    if (( $(echo "$quality_score >= 90" | bc -l) )); then
        mos=4.5
    elif (( $(echo "$quality_score >= 80" | bc -l) )); then
        mos=4.0
    elif (( $(echo "$quality_score >= 70" | bc -l) )); then
        mos=3.5
    elif (( $(echo "$quality_score >= 60" | bc -l) )); then
        mos=3.0
    elif (( $(echo "$quality_score >= 50" | bc -l) )); then
        mos=2.5
    elif (( $(echo "$quality_score >= 40" | bc -l) )); then
        mos=2.0
    else
        mos=1.5
    fi

    # Output comprehensive JSON
    cat <<EOF
{
  "target": "${target}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "metrics": {
    "latency_ms": ${latency},
    "jitter_ms": ${jitter},
    "packet_loss_pct": ${loss},
    "bandwidth_mbps": ${bandwidth}
  },
  "scores": {
    "overall_quality": ${quality_score},
    "grade": "${grade}",
    "category": "${category}",
    "mos": ${mos}
  },
  "suitability": {
    "voip": $([ "$quality_score" -ge 70 ] && echo "true" || echo "false"),
    "video_conferencing": $([ "$quality_score" -ge 75 ] && echo "true" || echo "false"),
    "streaming": $([ "$quality_score" -ge 60 ] && echo "true" || echo "false"),
    "gaming": $([ "$quality_score" -ge 80 ] && echo "true" || echo "false"),
    "browsing": $([ "$quality_score" -ge 40 ] && echo "true" || echo "false")
  }
}
EOF
}

# Compare quality between two routes
# Args: $1 = target, $2 = route1_metrics_json, $3 = route2_metrics_json
# Returns: JSON with comparison
compare_route_quality() {
    local target="$1"
    local route1_json="$2"
    local route2_json="$3"

    # Extract scores from JSON
    local score1=$(echo "$route1_json" | grep -oP '"overall_quality":\s*\K[\d.]+')
    local score2=$(echo "$route2_json" | grep -oP '"overall_quality":\s*\K[\d.]+')

    # Determine winner
    local winner="route1"
    local score_diff=$(echo "scale=2; ${score1} - ${score2}" | bc -l)

    if (( $(echo "$score2 > $score1" | bc -l) )); then
        winner="route2"
        score_diff=$(echo "scale=2; ${score2} - ${score1}" | bc -l)
    fi

    # Determine significance of difference
    local significance="NEGLIGIBLE"
    if (( $(echo "$score_diff >= 20" | bc -l) )); then
        significance="MAJOR"
    elif (( $(echo "$score_diff >= 10" | bc -l) )); then
        significance="SIGNIFICANT"
    elif (( $(echo "$score_diff >= 5" | bc -l) )); then
        significance="MODERATE"
    fi

    # Output comparison JSON
    cat <<EOF
{
  "target": "${target}",
  "route1_score": ${score1},
  "route2_score": ${score2},
  "winner": "${winner}",
  "score_difference": ${score_diff},
  "significance": "${significance}",
  "recommendation": "Use ${winner} for optimal performance"
}
EOF
}

# Calculate composite score for route selection
# Combines BGP intelligence with quality metrics
# Args: $1 = target, $2 = quality_score, $3 = as_hop_count, $4 = tier1_presence
# Returns: composite routing score (0-100)
calculate_composite_score() {
    local target="$1"
    local quality_score="$2"
    local as_hop_count="${3:-10}"
    local tier1_presence="${4:-0}"

    # Weights for composite score
    local QUALITY_WEIGHT=60
    local AS_PATH_WEIGHT=25
    local TIER1_WEIGHT=15

    # Calculate AS path score (fewer hops is better)
    local as_score=100
    if [ $as_hop_count -gt 10 ]; then
        as_score=0
    else
        as_score=$(echo "scale=2; 100 - (${as_hop_count} * 10)" | bc -l)
    fi

    # Tier1 score
    local tier1_score=$((tier1_presence * 100))

    # Composite calculation
    local composite=$(echo "scale=2; (${quality_score} * ${QUALITY_WEIGHT} / 100) + (${as_score} * ${AS_PATH_WEIGHT} / 100) + (${tier1_score} * ${TIER1_WEIGHT} / 100)" | bc -l)

    # Ensure 0-100 range
    if (( $(echo "$composite > 100" | bc -l) )); then
        composite=100
    elif (( $(echo "$composite < 0" | bc -l) )); then
        composite=0
    fi

    log_info "Composite routing score for ${target}: ${composite}/100"
    echo "$composite"
}

# Export functions
export -f estimate_bandwidth_ping
export -f measure_download_speed
export -f measure_bandwidth_iperf
export -f calculate_link_quality
export -f get_quality_grade
export -f assess_network_quality
export -f compare_route_quality
export -f calculate_composite_score
