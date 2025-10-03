#!/bin/bash
################################################################################
# NETOPT Service Logger - Enhanced Logging for systemd Services
# Integrates structured logging with systemd journal
################################################################################

set -euo pipefail

# Determine script location and load core logger
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOGGER_PATH="${SCRIPT_DIR}/lib/core/logger.sh"

if [[ -f "$LOGGER_PATH" ]]; then
    source "$LOGGER_PATH"
else
    # Fallback logging if core logger not available
    log_info() { echo "[INFO] $*"; }
    log_warn() { echo "[WARN] $*"; }
    log_error() { echo "[ERROR] $*"; }
    log_debug() { echo "[DEBUG] $*"; }
fi

################################################################################
# Service-Specific Logging Functions
################################################################################

log_service_start() {
    log_separator "="
    log_info "NETOPT Service Starting"
    log_separator "="
    log_info "Timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    log_info "Hostname: $(hostname)"
    log_info "User: ${USER:-root}"
    log_info "PID: $$"
    log_info "Working Directory: $(pwd)"
    log_separator "-"
}

log_service_stop() {
    log_separator "="
    log_info "NETOPT Service Stopping"
    log_separator "="
}

log_network_state() {
    local phase="${1:-current}"

    log_info "Network State ($phase):"

    # Active interfaces
    local active_ifaces=$(ip -br link show | grep -c "UP" || echo "0")
    log_info "  Active Interfaces: $active_ifaces"

    ip -br link show | grep "UP" | while read -r line; do
        log_info "    $line"
    done

    # Default routes
    log_info "  Default Routes:"
    ip route show default 2>/dev/null | while read -r route; do
        log_info "    $route"
    done || log_info "    None"

    # DNS servers
    if [[ -f /etc/resolv.conf ]]; then
        log_info "  DNS Servers:"
        grep "^nameserver" /etc/resolv.conf | while read -r ns; do
            log_info "    $ns"
        done
    fi
}

log_interface_test() {
    local iface="$1"
    local type="$2"
    local gateway="$3"

    log_info "Testing Interface: $iface ($type) via $gateway"
}

log_interface_test_result() {
    local iface="$1"
    local status="$2"  # alive or dead
    local latency="${3:-N/A}"
    local weight="${4:-N/A}"

    if [[ "$status" == "alive" ]]; then
        log_info "  ✓ ALIVE - Latency: ${latency}ms, Weight: $weight"
    else
        log_warn "  ✗ DEAD - Gateway not responding, skipping"
    fi
}

log_route_application() {
    local connection_count="$1"
    local connections_detail="$2"

    log_info "Applying load-balanced route with $connection_count connection(s)"
    log_info "  Configuration: $connections_detail"
}

log_route_success() {
    log_info "✓ Load balancing enabled successfully"
}

log_route_failure() {
    local error_msg="$1"
    log_error "✗ Route application failed: $error_msg"
    log_error "Initiating automatic rollback..."
}

log_tcp_optimization() {
    local param="$1"
    local value="$2"

    log_debug "TCP Optimization: $param = $value"
}

log_tcp_optimization_complete() {
    log_info "✓ TCP optimizations applied"

    # Log actual values
    log_debug "  tcp_congestion_control: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo 'unknown')"
    log_debug "  tcp_fastopen: $(sysctl -n net.ipv4.tcp_fastopen 2>/dev/null || echo 'unknown')"
    log_debug "  rmem_max: $(sysctl -n net.core.rmem_max 2>/dev/null || echo 'unknown')"
    log_debug "  wmem_max: $(sysctl -n net.core.wmem_max 2>/dev/null || echo 'unknown')"
}

log_dns_configuration() {
    local dns_type="$1"  # dnsmasq or direct
    shift
    local servers=("$@")

    log_info "Configuring DNS ($dns_type)"
    for server in "${servers[@]}"; do
        log_info "  Nameserver: $server"
    done
}

log_backup_created() {
    local backup_file="$1"
    local backup_size=$(du -h "$backup_file" 2>/dev/null | cut -f1 || echo "unknown")

    log_info "Backup created: $backup_file ($backup_size)"
}

log_checkpoint_created() {
    local checkpoint_name="$1"
    local checkpoint_path="$2"

    log_info "✓ Checkpoint created: $checkpoint_name"
    log_debug "  Location: $checkpoint_path"
}

log_performance_metric() {
    local metric_name="$1"
    local value="$2"
    local unit="${3:-}"

    log_debug "Performance: $metric_name = $value${unit}"
}

log_timing() {
    local operation="$1"
    local start_time="$2"
    local end_time="${3:-$(date +%s)}"

    local duration=$((end_time - start_time))
    log_info "⏱ $operation completed in ${duration}s"
}

################################################################################
# Structured JSON Logging for Monitoring Systems
################################################################################

log_json() {
    local level="$1"
    local message="$2"
    shift 2
    local extras=("$@")

    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')
    local hostname=$(hostname)

    # Build JSON
    local json="{"
    json+="\"timestamp\":\"$timestamp\","
    json+="\"level\":\"$level\","
    json+="\"message\":\"$message\","
    json+="\"service\":\"netopt\","
    json+="\"hostname\":\"$hostname\","
    json+="\"pid\":$$"

    # Add extra fields
    for extra in "${extras[@]}"; do
        if [[ "$extra" =~ ^([^=]+)=(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local val="${BASH_REMATCH[2]}"
            json+=",\"$key\":\"$val\""
        fi
    done

    json+="}"

    # Write to journal if available
    if command -v systemd-cat >/dev/null 2>&1; then
        echo "$json" | systemd-cat -t netopt -p info
    fi

    # Also write to structured log file
    local json_log="${NETOPT_LOG_DIR:-/var/log/netopt}/netopt.json"
    echo "$json" >> "$json_log" 2>/dev/null || true
}

log_event_json() {
    local event_type="$1"
    local event_action="$2"
    local event_result="$3"
    shift 3

    log_json "INFO" "$event_type: $event_action - $event_result" \
        "event_type=$event_type" \
        "event_action=$event_action" \
        "event_result=$event_result" \
        "$@"
}

################################################################################
# Service Lifecycle Logging
################################################################################

log_preflight_start() {
    log_section "Pre-flight Checks"
    log_info "Validating system state before optimization"
}

log_preflight_check() {
    local check_name="$1"
    local result="$2"
    local details="${3:-}"

    if [[ "$result" == "pass" ]]; then
        log_info "  ✓ $check_name ${details:+($details)}"
    elif [[ "$result" == "warn" ]]; then
        log_warn "  ⚠ $check_name ${details:+($details)}"
    else
        log_error "  ✗ $check_name ${details:+($details)}"
    fi
}

log_preflight_complete() {
    local passed="$1"
    local failed="$2"

    log_separator "-"
    log_info "Pre-flight Summary: ${passed} passed, ${failed} failed"

    if [[ $failed -gt 0 ]]; then
        log_error "Pre-flight checks failed, aborting"
        return 1
    fi

    log_info "All pre-flight checks passed"
    return 0
}

log_optimization_phase() {
    local phase="$1"

    log_section "$phase"
}

log_validation_start() {
    log_section "Post-Execution Validation"
    log_info "Verifying network optimizations"
}

log_validation_result() {
    local test_name="$1"
    local success="$2"
    local details="${3:-}"

    if [[ "$success" == "true" ]]; then
        log_info "  ✓ $test_name ${details:+($details)}"
    else
        log_error "  ✗ $test_name ${details:+($details)}"
    fi
}

################################################################################
# Performance and Metrics Logging
################################################################################

log_metrics_summary() {
    local interface_count="$1"
    local active_count="$2"
    local total_weight="$3"
    local avg_latency="$4"

    log_section "Optimization Metrics"
    log_info "Interfaces Detected: $interface_count"
    log_info "Active Connections: $active_count"
    log_info "Total Weight: $total_weight"
    log_info "Average Latency: ${avg_latency}ms"
    log_separator "-"
}

log_interface_metrics() {
    local iface="$1"
    local type="$2"
    local gateway="$3"
    local latency="$4"
    local weight="$5"
    local status="$6"

    log_json "INFO" "Interface metrics" \
        "interface=$iface" \
        "type=$type" \
        "gateway=$gateway" \
        "latency_ms=$latency" \
        "weight=$weight" \
        "status=$status"
}

################################################################################
# Export all functions
################################################################################

export -f log_service_start log_service_stop log_network_state
export -f log_interface_test log_interface_test_result
export -f log_route_application log_route_success log_route_failure
export -f log_tcp_optimization log_tcp_optimization_complete
export -f log_dns_configuration log_backup_created log_checkpoint_created
export -f log_performance_metric log_timing
export -f log_json log_event_json
export -f log_preflight_start log_preflight_check log_preflight_complete
export -f log_optimization_phase log_validation_start log_validation_result
export -f log_metrics_summary log_interface_metrics
