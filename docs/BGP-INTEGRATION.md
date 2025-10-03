# BGP Integration Documentation

## Overview

The NETOPT BGP integration provides intelligent network routing decisions based on BGP (Border Gateway Protocol) path analysis, combined with comprehensive network quality metrics. This integration enables the system to make informed routing choices by analyzing AS (Autonomous System) paths, network stability, and link quality.

## Architecture

### Core Components

1. **BGP Intelligence Module** (`lib/network/bgp-intelligence.sh`)
   - AS path discovery and tracing
   - BGP-aware weight calculation
   - Route comparison and optimization

2. **Stability Testing Module** (`lib/network/stability-testing.sh`)
   - Jitter measurement and analysis
   - Packet loss detection and burst analysis
   - MTU discovery and path optimization

3. **Metrics Module** (`lib/network/metrics.sh`)
   - Bandwidth estimation and measurement
   - Link quality scoring
   - Composite routing score calculation

4. **BGP Targets Configuration** (`config/bgp-targets.conf`)
   - Predefined major AS targets
   - Tier-1 transit providers
   - Content delivery networks
   - Regional testing targets

## Features

### AS Path Discovery

The BGP intelligence module uses `mtr` (My Traceroute) with AS lookup to discover the complete AS path to any target:

```bash
source lib/network/bgp-intelligence.sh

# Trace AS path to target
as_path=$(trace_as_path "8.8.8.8")
echo "AS Path: $as_path"
# Output: AS15169,AS3356,AS174

# Get AS number for specific IP
asn=$(get_as_number "1.1.1.1")
echo "AS Number: $asn"
# Output: AS13335

# Analyze AS path quality
analysis=$(analyze_as_path "8.8.8.8" "$as_path")
echo "$analysis"
```

### BGP-Aware Weight Calculation

Routes are scored using multiple factors:

- **Latency** (40% weight): Lower latency improves score
- **Packet Loss** (30% weight): Less loss improves score
- **AS Path Length** (30% weight): Fewer AS hops improves score
- **Tier-1 Bonus**: Routes through Tier-1 providers receive bonus points

```bash
# Calculate BGP-aware weight
weight=$(calculate_bgp_weight "8.8.8.8" "25.5" "0.5" "AS15169,AS3356")
echo "Route weight: $weight"

# Compare two routes
best_gateway=$(compare_bgp_routes "8.8.8.8" "192.168.1.1" "192.168.1.254")
echo "Best gateway: $best_gateway"
```

### Network Stability Testing

Comprehensive stability analysis includes:

#### Jitter Measurement

```bash
source lib/network/stability-testing.sh

# Quick jitter measurement
jitter=$(measure_jitter "8.8.8.8" 20)
echo "Jitter: ${jitter}ms"

# Comprehensive analysis
jitter_analysis=$(analyze_jitter "8.8.8.8" 30)
echo "$jitter_analysis"
# Returns JSON with mean, min, max, jitter, quality score
```

#### Packet Loss Analysis

```bash
# Basic packet loss measurement
loss=$(measure_packet_loss "8.8.8.8" 50)
echo "Packet loss: ${loss}%"

# Extended analysis with burst detection
loss_analysis=$(analyze_packet_loss "8.8.8.8" 30)
echo "$loss_analysis"
# Returns JSON with burst count, consecutive loss stats
```

#### MTU Discovery

```bash
# Discover optimal MTU
optimal_mtu=$(discover_mtu "8.8.8.8")
echo "Optimal MTU: ${optimal_mtu}"

# Comprehensive MTU analysis
mtu_analysis=$(analyze_mtu "8.8.8.8")
echo "$mtu_analysis"
# Returns JSON with optimal MTU, jumbo frame support, fragmentation info
```

#### Combined Stability Test

```bash
# Run all stability tests
stability=$(test_network_stability "8.8.8.8")
echo "$stability"
# Returns comprehensive JSON with all metrics and overall grade
```

### Quality Metrics and Scoring

#### Link Quality Calculation

Quality scores range from 0-100 based on:

- **Latency Score** (30 points max)
  - <10ms: 30 points
  - 10-30ms: 25 points
  - 30-50ms: 20 points
  - 50-100ms: 15 points
  - 100-200ms: 10 points
  - 200-300ms: 5 points

- **Jitter Score** (25 points max)
  - Based on jitter ratio (jitter/latency)
  - <5%: 25 points
  - 5-10%: 20 points
  - 10-15%: 15 points

- **Packet Loss Score** (30 points max)
  - 0%: 30 points
  - <0.5%: 28 points
  - <1%: 25 points
  - <2%: 20 points

- **Bandwidth Score** (15 points max)
  - ≥100 Mbps: 15 points
  - 50-100 Mbps: 12 points
  - 25-50 Mbps: 10 points

```bash
source lib/network/metrics.sh

# Calculate link quality
quality=$(calculate_link_quality "25.5" "2.3" "0.5" "100")
echo "Quality score: ${quality}/100"

# Get letter grade
grade=$(get_quality_grade "$quality")
echo "Grade: $grade"
```

#### Comprehensive Quality Assessment

```bash
# Complete network quality assessment
assessment=$(assess_network_quality "8.8.8.8")
echo "$assessment"
```

Returns JSON with:
- All metrics (latency, jitter, loss, bandwidth)
- Quality scores and grade
- MOS (Mean Opinion Score) for VoIP
- Suitability ratings for different applications

#### Bandwidth Testing

```bash
# Ping-based bandwidth estimation
bandwidth=$(estimate_bandwidth_ping "8.8.8.8")
echo "Estimated bandwidth: ${bandwidth} Mbps"

# HTTP download speed test
speed=$(measure_download_speed "http://speedtest.tele2.net/10MB.zip")
echo "Download speed: ${speed} Mbps"

# iperf3 bandwidth test (requires iperf3 server)
iperf_bw=$(measure_bandwidth_iperf "iperf.example.com")
echo "iperf3 bandwidth: ${iperf_bw} Mbps"
```

### Composite Routing Score

Combines BGP intelligence with quality metrics:

```bash
# Calculate composite score (60% quality, 25% AS path, 15% Tier-1)
composite=$(calculate_composite_score "8.8.8.8" "85" "3" "1")
echo "Composite routing score: ${composite}/100"
```

## BGP Targets Configuration

The `config/bgp-targets.conf` file contains predefined targets organized by category:

### Tier-1 Transit Providers

Major global transit networks:
- Cogent (AS174)
- Verizon Business (AS701)
- Telia (AS1299)
- NTT Communications (AS2914)
- Level 3/Lumen (AS3356)
- AT&T (AS7018)

### Content Providers

Major CDNs and cloud services:
- Google (AS15169)
- Cloudflare (AS13335)
- Amazon AWS (AS16509)
- Microsoft Azure (AS8075)
- Akamai (AS20940)

### Regional Internet Registries

- ARIN (North America)
- RIPE NCC (Europe)
- APNIC (Asia Pacific)
- LACNIC (Latin America)
- AFRINIC (Africa)

### Configuration Format

```
TARGET_NAME|IP_ADDRESS|AS_NUMBER|PRIORITY|REGION
GOOGLE_DNS1|8.8.8.8|AS15169|95|GLOBAL
```

## Usage Examples

### Example 1: Compare Two ISP Routes

```bash
#!/bin/bash
source lib/network/bgp-intelligence.sh
source lib/network/metrics.sh

TARGET="8.8.8.8"
ISP1_GATEWAY="192.168.1.1"
ISP2_GATEWAY="192.168.2.1"

# Compare routes using BGP intelligence
best_gateway=$(compare_bgp_routes "$TARGET" "$ISP1_GATEWAY" "$ISP2_GATEWAY")
echo "Best gateway for $TARGET: $best_gateway"

# Get detailed quality metrics
quality1=$(assess_network_quality "$TARGET")
echo "ISP1 Quality Assessment:"
echo "$quality1" | jq .

# Calculate composite scores
score1=$(calculate_composite_score "$TARGET" "85" "4" "1")
echo "ISP1 Composite Score: $score1"
```

### Example 2: Monitor Network Stability

```bash
#!/bin/bash
source lib/network/stability-testing.sh

TARGET="1.1.1.1"
LOGFILE="/var/log/netopt/stability.log"

while true; do
    # Run comprehensive stability test
    stability=$(test_network_stability "$TARGET")

    # Extract overall score
    score=$(echo "$stability" | jq -r '.overall_stability_score')
    grade=$(echo "$stability" | jq -r '.grade')

    echo "$(date): Stability to $TARGET - Score: $score, Grade: $grade" >> "$LOGFILE"

    # Alert if quality drops below threshold
    if (( $(echo "$score < 60" | bc -l) )); then
        echo "WARNING: Network stability degraded!" | mail -s "NETOPT Alert" admin@example.com
    fi

    sleep 300
done
```

### Example 3: Automatic Route Selection

```bash
#!/bin/bash
source lib/network/bgp-intelligence.sh
source lib/network/metrics.sh
source lib/network/stability-testing.sh

TARGET="8.8.8.8"
GATEWAYS=("192.168.1.1" "192.168.1.254")

best_score=0
best_gateway=""

for gw in "${GATEWAYS[@]}"; do
    echo "Testing gateway: $gw"

    # Trace AS path
    as_path=$(trace_as_path "$TARGET")
    as_hops=$(echo "$as_path" | tr ',' '\n' | wc -l)
    tier1=$(echo "$as_path" | grep -c 'AS174\|AS701\|AS1299\|AS3356' || echo 0)

    # Get quality metrics
    quality_json=$(assess_network_quality "$TARGET")
    quality_score=$(echo "$quality_json" | jq -r '.scores.overall_quality')

    # Calculate composite score
    composite=$(calculate_composite_score "$TARGET" "$quality_score" "$as_hops" "$tier1")

    echo "  AS hops: $as_hops, Tier-1: $tier1, Quality: $quality_score, Composite: $composite"

    if (( $(echo "$composite > $best_score" | bc -l) )); then
        best_score=$composite
        best_gateway=$gw
    fi
done

echo "Selected gateway: $best_gateway (score: $best_score)"

# Set default route
ip route del default
ip route add default via "$best_gateway"
```

### Example 4: BGP Target Testing

```bash
#!/bin/bash
source lib/network/bgp-intelligence.sh
source lib/network/metrics.sh

# Read BGP targets from config
while IFS='|' read -r name ip asn priority region; do
    # Skip comments and empty lines
    [[ "$name" =~ ^#.*$ ]] && continue
    [[ -z "$name" ]] && continue

    echo "Testing $name ($ip) - $asn in $region"

    # Get AS path
    as_path=$(trace_as_path "$ip")
    echo "  AS Path: $as_path"

    # Measure quality
    quality=$(assess_network_quality "$ip")
    score=$(echo "$quality" | jq -r '.scores.overall_quality')
    grade=$(echo "$quality" | jq -r '.scores.grade')

    echo "  Quality: $score/100 (Grade: $grade)"
    echo ""

done < <(grep -v '^#' config/bgp-targets.conf | grep -v '^$')
```

## Integration with NETOPT

### Automatic Integration

The BGP modules integrate seamlessly with the main NETOPT system:

```bash
# In main network-optimize.sh
source lib/network/bgp-intelligence.sh
source lib/network/stability-testing.sh
source lib/network/metrics.sh

# Use BGP-aware routing
optimize_routing_with_bgp() {
    local target="$1"
    local current_gw=$(ip route | grep default | awk '{print $3}')

    # Test current route
    current_quality=$(assess_network_quality "$target")
    current_score=$(echo "$current_quality" | jq -r '.scores.overall_quality')

    # Find alternative routes and compare
    # ... route discovery logic ...

    # Apply best route based on composite score
}
```

### Configuration Parameters

Key parameters in `config/bgp-targets.conf`:

```bash
# Test frequency (seconds)
BGP_TEST_INTERVAL=300

# Number of ping tests per target
BGP_PING_COUNT=10

# Timeout for trace operations (seconds)
BGP_TRACE_TIMEOUT=30

# Maximum AS path length
BGP_MAX_AS_PATH_LENGTH=15

# Weight coefficients
BGP_WEIGHT_LATENCY=40
BGP_WEIGHT_LOSS=30
BGP_WEIGHT_AS_PATH=30

# Feature flags
BGP_ENABLE_AS_DISCOVERY=1
BGP_PREFER_TIER1=1
BGP_LOG_LEVEL=INFO
```

## Dependencies

### Required Tools

- `mtr` - My Traceroute with AS lookup support
- `ping` - ICMP echo testing
- `ip` - IP routing utilities
- `bc` - Arbitrary precision calculator
- `jq` - JSON processor (for examples)

### Optional Tools

- `whois` - AS number lookup
- `curl` or `wget` - HTTP bandwidth testing
- `iperf3` - Network performance testing
- `traceroute` - Fallback route tracing

### Installation

```bash
# Debian/Ubuntu
apt-get install mtr-tiny iproute2 bc jq whois curl iperf3

# RHEL/CentOS
yum install mtr iproute bc jq whois curl iperf3

# Arch Linux
pacman -S mtr iproute2 bc jq whois curl iperf3
```

## Performance Considerations

### Test Duration

- Quick jitter test (20 packets): ~4-5 seconds
- Comprehensive jitter (30 packets): ~6-7 seconds
- Packet loss analysis (30 seconds): ~30-35 seconds
- MTU discovery: ~10-15 seconds
- Complete stability test: ~50-60 seconds
- AS path trace: ~5-10 seconds

### Resource Usage

- CPU: Minimal (mostly waiting for network responses)
- Memory: <10MB per test session
- Network: Variable, typically <5MB per comprehensive test

### Optimization Tips

1. **Parallel Testing**: Test multiple targets simultaneously
2. **Caching**: Cache AS path results for frequently tested targets
3. **Adaptive Intervals**: Adjust test frequency based on stability
4. **Selective Testing**: Focus on problematic routes

## Troubleshooting

### Common Issues

#### 1. AS Path Returns "UNKNOWN"

**Cause**: mtr not installed or AS lookup disabled

**Solution**:
```bash
# Install mtr with AS lookup support
apt-get install mtr-tiny

# Verify AS lookup works
mtr --aslookup --report-cycles=1 8.8.8.8
```

#### 2. Bandwidth Estimation Shows -1

**Cause**: curl/wget not available or target unreachable

**Solution**:
```bash
# Install required tools
apt-get install curl wget

# Test connectivity
ping -c 5 8.8.8.8
```

#### 3. High Jitter Values

**Cause**: Network congestion or unstable routing

**Solution**:
- Run tests during different times
- Check for local network issues
- Consider alternative routes

#### 4. MTU Discovery Fails

**Cause**: ICMP filtering or firewall rules

**Solution**:
```bash
# Test ICMP with DF bit
ping -M do -s 1472 8.8.8.8

# Check firewall rules
iptables -L -n | grep ICMP
```

## Best Practices

### 1. Regular Testing

- Test major targets every 5 minutes
- Test all configured targets hourly
- Perform comprehensive stability tests daily

### 2. Threshold Management

- Set quality thresholds based on application requirements
- VoIP: Quality score ≥70
- Video conferencing: Quality score ≥75
- Gaming: Quality score ≥80
- General browsing: Quality score ≥40

### 3. Route Selection

- Prefer routes with Tier-1 transit
- Consider AS path length
- Weight recent measurements higher
- Implement hysteresis to prevent route flapping

### 4. Logging and Monitoring

- Log all routing decisions
- Track quality trends over time
- Alert on significant degradation
- Maintain historical data for analysis

### 5. Fail-Safe Mechanisms

- Always have fallback routes
- Implement timeout protections
- Validate measurements before applying
- Test new routes before switching

## API Reference

### BGP Intelligence Module

```bash
trace_as_path <target>              # Returns AS path as comma-separated string
get_as_number <ip>                  # Returns AS number for IP
analyze_as_path <target> <as_path>  # Returns JSON with AS path metrics
calculate_bgp_weight <target> <latency> <loss> <as_path>  # Returns route weight
compare_bgp_routes <target> <gw1> <gw2>  # Returns best gateway
discover_bgp_peers                  # Returns list of BGP peers
```

### Stability Testing Module

```bash
measure_jitter <target> [count]     # Returns jitter in ms
analyze_jitter <target> [count]     # Returns JSON with jitter analysis
measure_packet_loss <target> [count]  # Returns loss percentage
analyze_packet_loss <target> [duration]  # Returns JSON with loss analysis
discover_mtu <target> [interface]   # Returns optimal MTU
analyze_mtu <target>                # Returns JSON with MTU analysis
test_network_stability <target>     # Returns comprehensive stability JSON
```

### Metrics Module

```bash
estimate_bandwidth_ping <target>    # Returns bandwidth estimate in Mbps
measure_download_speed [url]        # Returns download speed in Mbps
measure_bandwidth_iperf <server>    # Returns iperf3 bandwidth in Mbps
calculate_link_quality <latency> <jitter> <loss> <bandwidth>  # Returns 0-100 score
get_quality_grade <score>           # Returns letter grade A-F
assess_network_quality <target>     # Returns comprehensive quality JSON
compare_route_quality <target> <json1> <json2>  # Returns comparison JSON
calculate_composite_score <target> <quality> <as_hops> <tier1>  # Returns composite score
```

## Changelog

### Version 1.0.0 (2025-10-03)

- Initial BGP integration release
- AS path discovery using mtr
- BGP-aware weight calculation
- Comprehensive stability testing
- Multi-metric quality scoring
- Composite routing score calculation
- Major AS targets configuration
- Complete documentation

## Support

For issues, questions, or contributions:

- GitHub: [NETOPT Repository]
- Documentation: `/home/john/Downloads/NETOPT/docs/`
- Configuration: `/home/john/Downloads/NETOPT/config/bgp-targets.conf`

## License

Part of the NETOPT network optimization suite.
