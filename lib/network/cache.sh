#!/bin/bash
# Result Caching System for Network Optimization
# Implements time-based cache with 60-second TTL to avoid redundant gateway tests

CACHE_DIR="/var/cache/network-optimize"
CACHE_TTL=60  # Time-to-live in seconds

# Initialize cache directory
init_cache() {
    mkdir -p "$CACHE_DIR"
    chmod 755 "$CACHE_DIR"
}

# Generate cache key from interface and gateway
cache_key() {
    local iface=$1
    local gateway=$2
    echo "${iface}_${gateway//[.:]/_}"
}

# Check if cache entry exists and is still valid
cache_get() {
    local iface=$1
    local gateway=$2
    local key=$(cache_key "$iface" "$gateway")
    local cache_file="$CACHE_DIR/$key"

    # Check if cache file exists
    if [ ! -f "$cache_file" ]; then
        return 1  # Cache miss
    fi

    # Check if cache is still valid (not expired)
    local cache_time=$(stat -c %Y "$cache_file" 2>/dev/null)
    local current_time=$(date +%s)
    local age=$((current_time - cache_time))

    if [ $age -gt $CACHE_TTL ]; then
        # Cache expired, remove it
        rm -f "$cache_file"
        return 1  # Cache miss
    fi

    # Cache hit - return cached value
    cat "$cache_file"
    return 0
}

# Store value in cache
cache_set() {
    local iface=$1
    local gateway=$2
    local value=$3
    local key=$(cache_key "$iface" "$gateway")
    local cache_file="$CACHE_DIR/$key"

    echo "$value" > "$cache_file"
    return 0
}

# Invalidate cache entry
cache_invalidate() {
    local iface=$1
    local gateway=$2
    local key=$(cache_key "$iface" "$gateway")
    local cache_file="$CACHE_DIR/$key"

    rm -f "$cache_file"
    return 0
}

# Clear all cache entries
cache_clear_all() {
    rm -f "$CACHE_DIR"/*
    return 0
}

# Prune expired cache entries
cache_prune() {
    local current_time=$(date +%s)
    local pruned_count=0

    for cache_file in "$CACHE_DIR"/*; do
        [ -f "$cache_file" ] || continue

        local cache_time=$(stat -c %Y "$cache_file" 2>/dev/null)
        local age=$((current_time - cache_time))

        if [ $age -gt $CACHE_TTL ]; then
            rm -f "$cache_file"
            pruned_count=$((pruned_count + 1))
        fi
    done

    return $pruned_count
}

# Get cache statistics
cache_stats() {
    local total_entries=$(ls -1 "$CACHE_DIR" 2>/dev/null | wc -l)
    local current_time=$(date +%s)
    local valid_entries=0
    local expired_entries=0

    for cache_file in "$CACHE_DIR"/*; do
        [ -f "$cache_file" ] || continue

        local cache_time=$(stat -c %Y "$cache_file" 2>/dev/null)
        local age=$((current_time - cache_time))

        if [ $age -le $CACHE_TTL ]; then
            valid_entries=$((valid_entries + 1))
        else
            expired_entries=$((expired_entries + 1))
        fi
    done

    echo "Total: $total_entries, Valid: $valid_entries, Expired: $expired_entries"
}

# Cached gateway test function
# Returns cached result if available, otherwise tests and caches
test_gateway_cached() {
    local iface=$1
    local gateway=$2

    # Try to get from cache first
    local cached_result=$(cache_get "$iface" "$gateway")
    if [ $? -eq 0 ]; then
        echo "$cached_result"
        return 0
    fi

    # Cache miss - perform actual test
    # Use fast ping: 2 pings, 0.5s timeout, 0.2s interval
    local result=$(ping -c 2 -W 1 -i 0.2 -I "$iface" "$gateway" 2>/dev/null | \
                   grep "rtt min/avg/max" | awk -F'/' '{print $5}')

    if [ -z "$result" ]; then
        # Store failure in cache too (avoid retesting dead gateways)
        cache_set "$iface" "$gateway" "FAILED"
        return 1
    fi

    # Round and cache the result
    local latency="${result%.*}"
    cache_set "$iface" "$gateway" "$latency"
    echo "$latency"
    return 0
}

# Batch cache operations
cache_get_or_test_batch() {
    declare -A BATCH_RESULTS
    local cache_hits=0
    local cache_misses=0

    for arg in "$@"; do
        IFS=':' read -r iface gateway <<< "$arg"

        local cached_result=$(cache_get "$iface" "$gateway")
        if [ $? -eq 0 ]; then
            BATCH_RESULTS["$iface"]="$cached_result"
            cache_hits=$((cache_hits + 1))
        else
            # Mark for testing
            BATCH_RESULTS["$iface"]="NEEDS_TEST"
            cache_misses=$((cache_misses + 1))
        fi
    done

    # Export results
    export BATCH_RESULTS
    export CACHE_HITS=$cache_hits
    export CACHE_MISSES=$cache_misses
}

# Auto-cleanup: Remove cache entries older than TTL on startup
auto_cleanup_cache() {
    init_cache
    cache_prune
}

# Export functions for use in other scripts
export -f init_cache
export -f cache_key
export -f cache_get
export -f cache_set
export -f cache_invalidate
export -f cache_clear_all
export -f cache_prune
export -f cache_stats
export -f test_gateway_cached
export -f cache_get_or_test_batch
export -f auto_cleanup_cache
