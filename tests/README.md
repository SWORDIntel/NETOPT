# NETOPT Testing Framework

Comprehensive testing suite for the Network Optimization and Load Balancing tool.

## Table of Contents

- [Overview](#overview)
- [Test Structure](#test-structure)
- [Prerequisites](#prerequisites)
- [Running Tests](#running-tests)
- [Test Categories](#test-categories)
- [CI/CD Integration](#cicd-integration)
- [Writing New Tests](#writing-new-tests)
- [Troubleshooting](#troubleshooting)

## Overview

The NETOPT testing framework provides comprehensive test coverage across multiple categories:

- **Unit Tests**: Test individual functions in isolation
- **Integration Tests**: Test complete workflows with simulated networks
- **Performance Tests**: Benchmark execution speed and resource usage
- **Stability Tests**: Long-running tests for reliability

## Test Structure

```
tests/
├── unit/                           # Unit tests
│   ├── test_interface_detection.bats   # Interface type detection
│   └── test_weight_calculation.bats    # Weight calculation logic
├── integration/                    # Integration tests
│   ├── network_simulator.sh           # Virtual network setup tool
│   └── test_multi_interface.bats      # Multi-interface scenarios
├── performance/                    # Performance benchmarks
│   ├── benchmark.sh                   # Benchmark suite
│   └── results/                       # Benchmark results
├── stability/                      # Long-running tests
├── test_helper.bash               # Shared test utilities
└── README.md                      # This file
```

## Prerequisites

### Required Packages

#### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install -y bats bc iproute2 iputils-ping bridge-utils
```

#### RHEL/CentOS/Fedora
```bash
sudo yum install -y bats bc iproute iputils bridge-utils
```

#### Arch Linux
```bash
sudo pacman -S bats bc iproute2 iputils bridge-utils
```

### Optional Packages

For enhanced testing capabilities:
```bash
# BATS support libraries
sudo apt-get install -y bats-support bats-assert

# Code coverage
sudo apt-get install -y kcov

# Shell linting
sudo apt-get install -y shellcheck
```

## Running Tests

### Quick Start

Run all tests:
```bash
# Unit tests (no root required)
bats tests/unit/

# Integration tests (requires root)
sudo bats tests/integration/

# Performance benchmarks
sudo tests/performance/benchmark.sh all
```

### Individual Test Suites

#### Unit Tests

Test interface detection:
```bash
bats tests/unit/test_interface_detection.bats
```

Test weight calculation:
```bash
bats tests/unit/test_weight_calculation.bats
```

#### Integration Tests

Setup test environment:
```bash
sudo tests/integration/network_simulator.sh setup
```

Run integration tests:
```bash
sudo bats tests/integration/test_multi_interface.bats
```

Cleanup test environment:
```bash
sudo tests/integration/network_simulator.sh cleanup
```

#### Performance Benchmarks

Run all benchmarks:
```bash
sudo tests/performance/benchmark.sh all
```

Run specific benchmarks:
```bash
# Function performance
tests/performance/benchmark.sh functions

# Scaling tests
tests/performance/benchmark.sh scaling

# Weight calculation performance
tests/performance/benchmark.sh weight

# Script startup time
tests/performance/benchmark.sh startup

# Route operations (requires root)
sudo tests/performance/benchmark.sh routes
```

Compare with previous results:
```bash
tests/performance/benchmark.sh compare tests/performance/results/benchmark_20231015_143022.txt
```

## Test Categories

### Unit Tests

Unit tests verify individual functions in isolation without requiring network access or root privileges.

**Coverage:**
- Interface type detection (ethernet, wifi, mobile, unknown)
- Priority assignment (10, 20, 30, 40)
- Weight calculation with various latencies
- Edge cases and boundary conditions

**Example:**
```bash
@test "detect_interface_type: ethernet interface with 'eth' prefix" {
    result=$(detect_interface_type "eth0")
    [ "$result" = "ethernet" ]
}
```

### Integration Tests

Integration tests create virtual network environments using network namespaces to simulate real-world scenarios.

**Coverage:**
- Multi-interface setup and detection
- Route backup and restore
- Interface failure handling
- Multipath routing with weights
- End-to-end workflows

**Network Simulator:**

The `network_simulator.sh` tool creates virtual interfaces with configurable latency:

```bash
# Create test environment
sudo tests/integration/network_simulator.sh setup

# This creates:
# - 3 network namespaces (ethernet, wifi, mobile)
# - 3 veth pairs with different latencies
# - 1 bridge connecting all interfaces

# Simulate interface failure
sudo tests/integration/network_simulator.sh fail veth_test_eth_host

# Simulate recovery
sudo tests/integration/network_simulator.sh recover veth_test_eth_host

# Add custom latency
sudo tests/integration/network_simulator.sh latency veth_test_eth_host 100

# Check status
sudo tests/integration/network_simulator.sh status

# Cleanup
sudo tests/integration/network_simulator.sh cleanup
```

### Performance Tests

Performance tests measure execution speed, resource usage, and scalability.

**Metrics:**
- Function execution time
- Script startup time
- Memory usage
- CPU utilization
- Interface scaling (1, 5, 10, 20, 50 interfaces)
- Route operation speed

**Example output:**
```
[BENCHMARK] Benchmarking function execution speed
  detect_interface_type: 0.000123s (avg over 1000 calls)
  calculate_weight: 0.000098s (avg over 1000 calls)

[BENCHMARK] Benchmarking interface detection scalability
  1 interfaces: 0.001234s
  5 interfaces: 0.005678s
  10 interfaces: 0.011234s
  20 interfaces: 0.022456s
  50 interfaces: 0.055789s
```

## CI/CD Integration

### GitHub Actions

The testing framework integrates with GitHub Actions for automated testing.

**Workflow:** `.github/workflows/test.yml`

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Daily scheduled runs (2 AM UTC)

**Jobs:**
1. **Unit Tests** - Run on every commit
2. **Integration Tests** - Run with elevated privileges
3. **Performance Tests** - Generate benchmark reports
4. **ShellCheck** - Lint shell scripts
5. **Security Scan** - Check for hardcoded secrets and dangerous commands
6. **Compatibility Tests** - Test on Ubuntu 20.04, 22.04, 24.04
7. **Code Coverage** - Generate coverage reports

**Local GitHub Actions testing:**
```bash
# Install act (GitHub Actions local runner)
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Run workflows locally
act -j unit-tests
act -j integration-tests
```

### Adding CI/CD to Your Repository

1. Ensure `.github/workflows/test.yml` is in your repository
2. Push to GitHub
3. Tests will run automatically on push/PR
4. Check the "Actions" tab for results

## Writing New Tests

### BATS Test Syntax

BATS (Bash Automated Testing System) uses a simple syntax:

```bash
#!/usr/bin/env bats

# Load test helpers
load '../test_helper'

# Setup runs before each test
setup() {
    export TEST_DIR=$(mktemp -d)
}

# Teardown runs after each test
teardown() {
    rm -rf "$TEST_DIR"
}

# Test case
@test "description of what this tests" {
    # Arrange
    local input="eth0"

    # Act
    result=$(detect_interface_type "$input")

    # Assert
    [ "$result" = "ethernet" ]
}

# Test with run command (captures exit code and output)
@test "function returns correct exit code" {
    run some_function
    [ "$status" -eq 0 ]
    [[ "$output" =~ "expected string" ]]
}
```

### Test Helper Functions

Available in `test_helper.bash`:

```bash
# Mock commands
mock_ip "link show"
mock_ping -c 3 -W 1 -I eth0 192.168.1.1

# Network utilities
setup_netns "my_namespace"
cleanup_netns "my_namespace"
create_veth_pair "veth0" "veth1"

# Assertions
assert_contains "$output" "expected text"
assert_not_contains "$output" "unexpected text"
assert_greater_than "$a" "$b"
assert_less_than "$a" "$b"

# Requirements
require_root          # Skip test if not root
require_command kcov  # Skip if command not available
```

### Adding a New Unit Test

1. Create test file: `tests/unit/test_new_feature.bats`

```bash
#!/usr/bin/env bats

load '../test_helper'

setup() {
    source "${NETOPT_ROOT}/network-optimize.sh"
}

@test "new feature: basic functionality" {
    result=$(new_function "input")
    [ "$result" = "expected" ]
}

@test "new feature: edge case" {
    result=$(new_function "")
    [ "$result" = "default" ]
}
```

2. Run your test:
```bash
bats tests/unit/test_new_feature.bats
```

### Adding a New Integration Test

1. Update `network_simulator.sh` if needed to create test environment
2. Add test to `tests/integration/test_multi_interface.bats`

```bash
@test "integration: test new scenario" {
    "$SIMULATOR" setup

    # Your test logic here

    "$SIMULATOR" cleanup
}
```

## Troubleshooting

### Common Issues

#### Permission Denied

**Problem:** Integration tests fail with permission errors

**Solution:**
```bash
# Run with sudo
sudo bats tests/integration/test_multi_interface.bats

# Or add your user to required groups
sudo usermod -aG netdev,docker $USER
```

#### BATS Not Found

**Problem:** `bats: command not found`

**Solution:**
```bash
# Install BATS
sudo apt-get install bats

# Or install from source
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

#### Network Namespace Errors

**Problem:** `Cannot create namespace: Operation not permitted`

**Solution:**
```bash
# Enable unprivileged namespace creation
sudo sysctl -w kernel.unprivileged_userns_clone=1

# Or run with sudo
sudo bats tests/integration/test_multi_interface.bats
```

#### Test Environment Not Cleaned Up

**Problem:** Previous test resources still exist

**Solution:**
```bash
# Manual cleanup
sudo tests/integration/network_simulator.sh cleanup

# Remove any lingering namespaces
sudo ip netns list | grep netopt_test | xargs -r -n1 sudo ip netns del

# Remove test interfaces
sudo ip link show | grep veth_test | awk '{print $2}' | cut -d@ -f1 | xargs -r -n1 sudo ip link del
```

#### Tests Fail on Different Kernel Versions

**Problem:** Multipath routing tests fail

**Solution:**
```bash
# Check kernel support
modprobe ipv6
ip route help | grep -q nexthop || echo "Multipath routing not supported"

# Tests should skip gracefully if feature not supported
```

### Debug Mode

Run tests with debug output:

```bash
# Verbose BATS output
bats -t tests/unit/test_interface_detection.bats

# Show command traces
bash -x tests/performance/benchmark.sh functions

# Enable script debug mode
export DEBUG=1
bats tests/integration/test_multi_interface.bats
```

### Getting Help

1. Check test output for specific error messages
2. Review logs in `/var/log/network-optimize.log`
3. Verify all prerequisites are installed
4. Check GitHub Issues for similar problems
5. Run tests individually to isolate failures

## Test Coverage Summary

| Component | Unit Tests | Integration Tests | Performance Tests |
|-----------|-----------|-------------------|-------------------|
| Interface Detection | ✅ 20 tests | ✅ 5 tests | ✅ Included |
| Weight Calculation | ✅ 25 tests | ✅ 3 tests | ✅ Included |
| Route Management | ✅ N/A | ✅ 8 tests | ✅ Included |
| Multi-interface | ✅ N/A | ✅ 12 tests | ✅ Included |
| Error Handling | ✅ 8 tests | ✅ 4 tests | ✅ N/A |

**Total Test Count:** 85+ tests

## Contributing

When adding new features:

1. Write unit tests for new functions
2. Add integration tests for workflows
3. Update performance benchmarks if needed
4. Ensure all tests pass before submitting PR
5. Update this README if adding new test categories

### Test Quality Checklist

- [ ] Tests are independent (no shared state)
- [ ] Tests clean up resources (in teardown)
- [ ] Tests have descriptive names
- [ ] Edge cases are covered
- [ ] Root-required tests skip gracefully
- [ ] Mock external dependencies
- [ ] Tests are deterministic (no random failures)

## License

Same as NETOPT project license.
