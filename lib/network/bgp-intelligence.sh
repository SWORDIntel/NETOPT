#!/bin/bash

#########################################
# BGP Intelligence Module
# AS Path Discovery and BGP-Aware Routing
#########################################

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/logging.sh" 2>/dev/null || true

#########################################
# AS Path Discovery Functions
#########################################

# Trace AS path to target using mtr
# Args: $1 = target IP/hostname
# Returns: AS path information
trace_as_path() {
    local target="$1"
    local mtr_output
    local as_path=()

    log_info "Tracing AS path to ${target}..."

    # Check if mtr is available
    if ! command -v mtr &> /dev/null; then
        log_warning "mtr not installed, AS path discovery unavailable"
        echo "UNKNOWN"
        return 1
    fi

    # Run mtr with AS lookup (-z flag) and parse output
    # Using --report mode for non-interactive output
    mtr_output=$(mtr --report --report-cycles=3 --aslookup "${target}" 2>/dev/null)

    if [ $? -ne 0 ]; then
        log_error "Failed to trace route to ${target}"
        echo "UNREACHABLE"
        return 1
    fi

    # Parse AS numbers from mtr output
    # mtr output format: Hop | AS# | Loss% | Snt | Last | Avg | Best | Wrst | StDev
    local as_numbers=$(echo "$mtr_output" | grep -oP 'AS\d+' | sort -u)

    if [ -z "$as_numbers" ]; then
        log_warning "No AS path found for ${target}"
        echo "UNKNOWN"
        return 1
    fi

    # Build AS path array
    local as_path_str=""
    while IFS= read -r asn; do
        as_path_str="${as_path_str} ${asn}"
    done <<< "$as_numbers"

    echo "${as_path_str// /,}" | sed 's/^,//'
    return 0
}

# Get AS number for a specific IP
# Args: $1 = IP address
# Returns: AS number or UNKNOWN
get_as_number() {
    local ip="$1"
    local asn

    # Try whois lookup for AS number
    if command -v whois &> /dev/null; then
        asn=$(whois -h whois.cymru.com " -v ${ip}" 2>/dev/null | tail -n1 | awk '{print $1}')

        if [ -n "$asn" ] && [ "$asn" != "NA" ]; then
            echo "AS${asn}"
            return 0
        fi
    fi

    # Fallback: try to extract from mtr
    if command -v mtr &> /dev/null; then
        asn=$(mtr --report --report-cycles=1 --aslookup "${ip}" 2>/dev/null | grep "${ip}" | grep -oP 'AS\d+' | head -1)

        if [ -n "$asn" ]; then
            echo "$asn"
            return 0
        fi
    fi

    echo "UNKNOWN"
    return 1
}

# Analyze AS path quality metrics
# Args: $1 = target, $2 = as_path
# Returns: JSON with AS path metrics
analyze_as_path() {
    local target="$1"
    local as_path="$2"
    local hop_count=0
    local known_good_transit=0

    # Count AS hops
    hop_count=$(echo "$as_path" | tr ',' '\n' | wc -l)

    # Check for known good transit providers (Tier 1 networks)
    local tier1_providers=("AS174" "AS701" "AS1299" "AS2914" "AS3257" "AS3356" "AS3491" "AS5511" "AS6453" "AS6461" "AS6762" "AS7018")

    for transit_as in "${tier1_providers[@]}"; do
        if echo "$as_path" | grep -q "$transit_as"; then
            ((known_good_transit++))
        fi
    done

    # Calculate AS path score (lower is better)
    # Score factors: hop count (weight: 0.5), tier1 presence (weight: 0.5)
    local hop_score=$((hop_count * 10))
    local transit_bonus=$((known_good_transit * 20))
    local total_score=$((hop_score - transit_bonus))

    # Ensure score is not negative
    [ $total_score -lt 0 ] && total_score=0

    # Output JSON format
    cat <<EOF
{
  "target": "${target}",
  "as_path": "${as_path}",
  "hop_count": ${hop_count},
  "tier1_transit": ${known_good_transit},
  "path_score": ${total_score}
}
EOF
}

#########################################
# BGP-Aware Weight Calculation
#########################################

# Calculate BGP-aware route weight
# Args: $1 = target, $2 = latency_ms, $3 = packet_loss_pct, $4 = as_path
# Returns: Weighted score (lower is better)
calculate_bgp_weight() {
    local target="$1"
    local latency="$2"
    local packet_loss="$3"
    local as_path="$4"

    # Default weights if parameters are missing
    latency=${latency:-999}
    packet_loss=${packet_loss:-100}
    as_path=${as_path:-"UNKNOWN"}

    # Weight factors
    local LATENCY_WEIGHT=40
    local LOSS_WEIGHT=30
    local AS_PATH_WEIGHT=30

    # Calculate AS path penalty
    local as_hop_count=1
    if [ "$as_path" != "UNKNOWN" ] && [ "$as_path" != "UNREACHABLE" ]; then
        as_hop_count=$(echo "$as_path" | tr ',' '\n' | wc -l)
    else
        as_hop_count=10  # High penalty for unknown paths
    fi

    # Check for Tier-1 transit bonus
    local tier1_bonus=0
    local tier1_providers=("AS174" "AS701" "AS1299" "AS2914" "AS3257" "AS3356" "AS3491" "AS5511" "AS6453" "AS6461" "AS6762" "AS7018")

    for transit_as in "${tier1_providers[@]}"; do
        if echo "$as_path" | grep -q "$transit_as"; then
            tier1_bonus=10
            break
        fi
    done

    # Calculate component scores
    local latency_score=$(echo "scale=2; ${latency} * ${LATENCY_WEIGHT} / 100" | bc -l 2>/dev/null || echo "$latency")
    local loss_score=$(echo "scale=2; ${packet_loss} * ${LOSS_WEIGHT} * 10" | bc -l 2>/dev/null || echo "$packet_loss")
    local as_score=$(echo "scale=2; ${as_hop_count} * ${AS_PATH_WEIGHT} / 10" | bc -l 2>/dev/null || echo "$as_hop_count")

    # Total weight calculation
    local total_weight=$(echo "scale=2; ${latency_score} + ${loss_score} + ${as_score} - ${tier1_bonus}" | bc -l 2>/dev/null || echo "999")

    # Ensure non-negative
    if (( $(echo "$total_weight < 0" | bc -l 2>/dev/null) )); then
        total_weight=0
    fi

    echo "$total_weight"
}

# Compare routes using BGP intelligence
# Args: $1 = target, $2 = gateway1, $3 = gateway2
# Returns: Best gateway
compare_bgp_routes() {
    local target="$1"
    local gw1="$2"
    local gw2="$3"

    log_info "Comparing BGP routes to ${target} via ${gw1} vs ${gw2}..."

    # Test route via gateway 1
    local as_path1=$(trace_as_path "${target}")
    local latency1=$(ping -c 3 -I "${gw1}" "${target}" 2>/dev/null | grep 'avg' | awk -F'/' '{print $5}' || echo "999")
    local loss1=$(ping -c 10 -I "${gw1}" "${target}" 2>/dev/null | grep 'packet loss' | grep -oP '\d+(?=%)' || echo "100")

    local weight1=$(calculate_bgp_weight "${target}" "${latency1}" "${loss1}" "${as_path1}")

    # Test route via gateway 2
    local as_path2=$(trace_as_path "${target}")
    local latency2=$(ping -c 3 -I "${gw2}" "${target}" 2>/dev/null | grep 'avg' | awk -F'/' '{print $5}' || echo "999")
    local loss2=$(ping -c 10 -I "${gw2}" "${target}" 2>/dev/null | grep 'packet loss' | grep -oP '\d+(?=%)' || echo "100")

    local weight2=$(calculate_bgp_weight "${target}" "${latency2}" "${loss2}" "${as_path2}")

    log_info "Route 1 (${gw1}): weight=${weight1}, latency=${latency1}ms, loss=${loss1}%, AS path=${as_path1}"
    log_info "Route 2 (${gw2}): weight=${weight2}, latency=${latency2}ms, loss=${loss2}%, AS path=${as_path2}"

    # Compare weights (lower is better)
    if (( $(echo "$weight1 < $weight2" | bc -l 2>/dev/null || echo "0") )); then
        echo "${gw1}"
    else
        echo "${gw2}"
    fi
}

#########################################
# BGP Target Discovery
#########################################

# Discover BGP peers from routing table
# Returns: List of BGP peer IPs
discover_bgp_peers() {
    local peers=()

    log_info "Discovering BGP peers..."

    # Try to find BGP peers from routing table
    # Look for routes with specific AS paths or BGP next-hop attributes

    if command -v ip &> /dev/null; then
        # Get all gateways from routing table
        local gateways=$(ip route show | grep -oP 'via \K[\d.]+' | sort -u)

        while IFS= read -r gw; do
            [ -z "$gw" ] && continue

            # Check if gateway might be a BGP peer (has AS number)
            local asn=$(get_as_number "$gw")

            if [ "$asn" != "UNKNOWN" ]; then
                peers+=("${gw}:${asn}")
                log_info "Found potential BGP peer: ${gw} (${asn})"
            fi
        done <<< "$gateways"
    fi

    # Output peers
    printf '%s\n' "${peers[@]}"
}

# Export functions
export -f trace_as_path
export -f get_as_number
export -f analyze_as_path
export -f calculate_bgp_weight
export -f compare_bgp_routes
export -f discover_bgp_peers
