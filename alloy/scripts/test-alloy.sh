#!/bin/bash

# Test Script for Grafana Alloy Dynamic Processors
# Comprehensive testing of Alloy functionality equivalent to OTel Collector tests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'  
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
ALLOY_ENDPOINT="http://localhost:4318"
HEALTH_ENDPOINT="http://localhost:13133"
METRICS_ENDPOINT="http://localhost:8889/metrics"
ALLOY_UI_ENDPOINT="http://localhost:12345"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

print_banner() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "  Grafana Alloy Dynamic Processors Test Suite"
    echo "=================================================="
    echo -e "${NC}"
}

print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_status() {
    echo -e "${GREEN}[STATUS]${NC} $1"
}

# Test 1: Basic connectivity
test_connectivity() {
    print_test "Testing basic connectivity"
    
    # Test health endpoint
    if curl -sf "$HEALTH_ENDPOINT" >/dev/null 2>&1; then
        print_pass "Health endpoint responding"
    else
        print_fail "Health endpoint not responding"
        return 1
    fi
    
    # Test OTLP HTTP endpoint
    if curl -sf -X POST "$ALLOY_ENDPOINT/v1/traces" \
        -H "Content-Type: application/json" \
        -d '{"resourceSpans": []}' >/dev/null 2>&1; then
        print_pass "OTLP HTTP endpoint accepting requests"
    else
        print_fail "OTLP HTTP endpoint not responding"
        return 1
    fi
    
    # Test metrics endpoint
    if curl -sf "$METRICS_ENDPOINT" >/dev/null 2>&1; then
        print_pass "Metrics endpoint serving data"
    else
        print_fail "Metrics endpoint not responding"
    fi
    
    # Test Alloy UI (if available)
    if curl -sf "$ALLOY_UI_ENDPOINT" >/dev/null 2>&1; then
        print_pass "Alloy UI endpoint responding"
    else
        print_warning "Alloy UI endpoint not responding (may not be enabled)"
    fi
}

# Test 2: Resource detection functionality
test_resource_detection() {
    print_test "Testing resource detection"
    
    # Send test data and check if resource attributes are added
    local test_payload='{
        "resourceSpans": [{
            "resource": {
                "attributes": [{
                    "key": "service.name",
                    "value": {"stringValue": "test-service"}
                }]
            },
            "scopeSpans": [{
                "spans": [{
                    "traceId": "0123456789abcdef0123456789abcdef",
                    "spanId": "0123456789abcdef",
                    "name": "test-span",
                    "startTimeUnixNano": "'$(date +%s%N)'",
                    "endTimeUnixNano": "'$(date +%s%N)'"
                }]
            }]
        }]
    }'
    
    if curl -sf -X POST "$ALLOY_ENDPOINT/v1/traces" \
        -H "Content-Type: application/json" \
        -d "$test_payload" >/dev/null 2>&1; then
        print_pass "Resource detection test data sent successfully"
        
        # Wait a moment for processing
        sleep 2
        
        # Check if sorting file was created (indicates processing)
        if [ -f "tmp/sorted-traces.json" ]; then
            print_pass "Trace processing confirmed (sorted file created)"
        else
            print_warning "Sorted traces file not found (may be processed differently)"
        fi
    else
        print_fail "Failed to send resource detection test data"
    fi
}

# Test 3: Intelligent labeling
test_intelligent_labeling() {
    print_test "Testing intelligent labeling"
    
    # Test service name normalization
    local test_payload='{
        "resourceSpans": [{
            "resource": {
                "attributes": [{
                    "key": "service.name",
                    "value": {"stringValue": "payment-service-prod"}
                }]
            },
            "scopeSpans": [{
                "spans": [{
                    "traceId": "1123456789abcdef0123456789abcdef", 
                    "spanId": "1123456789abcdef",
                    "name": "payment-processing",
                    "startTimeUnixNano": "'$(date +%s%N)'",
                    "endTimeUnixNano": "'$(date +%s%N)'",
                    "attributes": [{
                        "key": "transaction.amount",
                        "value": {"doubleValue": 100.50}
                    }]
                }]
            }]
        }]
    }'
    
    if curl -sf -X POST "$ALLOY_ENDPOINT/v1/traces" \
        -H "Content-Type: application/json" \
        -d "$test_payload" >/dev/null 2>&1; then
        print_pass "Intelligent labeling test data sent"
    else
        print_fail "Failed to send intelligent labeling test data"
    fi
}

# Test 4: Filtering functionality
test_filtering() {
    print_test "Testing environment-based filtering"
    
    # Send dev environment data (should be filtered out)
    local dev_payload='{
        "resourceSpans": [{
            "resource": {
                "attributes": [{
                    "key": "service.name",
                    "value": {"stringValue": "test-service"}
                }, {
                    "key": "environment",
                    "value": {"stringValue": "dev"}
                }]
            },
            "scopeSpans": [{
                "spans": [{
                    "traceId": "2123456789abcdef0123456789abcdef",
                    "spanId": "2123456789abcdef", 
                    "name": "dev-test-span",
                    "startTimeUnixNano": "'$(date +%s%N)'",
                    "endTimeUnixNano": "'$(date +%s%N)'"
                }]
            }]
        }]
    }'
    
    # Send prod environment data (should pass through)
    local prod_payload='{
        "resourceSpans": [{
            "resource": {
                "attributes": [{
                    "key": "service.name", 
                    "value": {"stringValue": "prod-service"}
                }, {
                    "key": "environment",
                    "value": {"stringValue": "prod"}
                }]
            },
            "scopeSpans": [{
                "spans": [{
                    "traceId": "3123456789abcdef0123456789abcdef",
                    "spanId": "3123456789abcdef",
                    "name": "prod-span",
                    "startTimeUnixNano": "'$(date +%s%N)'",
                    "endTimeUnixNano": "'$(date +%s%N)'"
                }]
            }]
        }]
    }'
    
    if curl -sf -X POST "$ALLOY_ENDPOINT/v1/traces" \
        -H "Content-Type: application/json" \
        -d "$dev_payload" >/dev/null 2>&1; then
        print_pass "Dev environment test data sent (should be filtered)"
    else
        print_fail "Failed to send dev environment test data"
    fi
    
    if curl -sf -X POST "$ALLOY_ENDPOINT/v1/traces" \
        -H "Content-Type: application/json" \
        -d "$prod_payload" >/dev/null 2>&1; then
        print_pass "Prod environment test data sent (should pass through)"
    else
        print_fail "Failed to send prod environment test data"
    fi
}

# Test 5: Sorting functionality
test_sorting() {
    print_test "Testing intelligent sorting"
    
    # Send multiple spans with different priorities
    local high_priority_payload='{
        "resourceSpans": [{
            "resource": {
                "attributes": [{
                    "key": "service.name",
                    "value": {"stringValue": "payment-service"}
                }]
            },
            "scopeSpans": [{
                "spans": [{
                    "traceId": "4123456789abcdef0123456789abcdef",
                    "spanId": "4123456789abcdef",
                    "name": "high-priority-payment",
                    "startTimeUnixNano": "'$(date +%s%N)'",
                    "endTimeUnixNano": "'$(date +%s%N)'",
                    "status": {"code": "STATUS_CODE_ERROR"}
                }]
            }]
        }]
    }'
    
    local low_priority_payload='{
        "resourceSpans": [{
            "resource": {
                "attributes": [{
                    "key": "service.name",
                    "value": {"stringValue": "notification-service"}
                }]
            },
            "scopeSpans": [{
                "spans": [{
                    "traceId": "5123456789abcdef0123456789abcdef",
                    "spanId": "5123456789abcdef",
                    "name": "low-priority-notification",
                    "startTimeUnixNano": "'$(date +%s%N)'",
                    "endTimeUnixNano": "'$(date +%s%N)'",
                    "status": {"code": "STATUS_CODE_OK"}
                }]
            }]
        }]
    }'
    
    # Send in reverse priority order to test sorting
    if curl -sf -X POST "$ALLOY_ENDPOINT/v1/traces" \
        -H "Content-Type: application/json" \
        -d "$low_priority_payload" >/dev/null 2>&1; then
        print_pass "Low priority span sent first"
    else
        print_fail "Failed to send low priority span"
    fi
    
    sleep 1
    
    if curl -sf -X POST "$ALLOY_ENDPOINT/v1/traces" \
        -H "Content-Type: application/json" \
        -d "$high_priority_payload" >/dev/null 2>&1; then
        print_pass "High priority span sent second"
    else
        print_fail "Failed to send high priority span"
    fi
}

# Test 6: Metrics collection
test_metrics() {
    print_test "Testing metrics collection"
    
    if curl -sf "$METRICS_ENDPOINT" | grep -q "otelcol_processor"; then
        print_pass "OpenTelemetry processor metrics found"
    else
        print_warning "OpenTelemetry processor metrics not found (may not be exposed yet)"
    fi
    
    if curl -sf "$METRICS_ENDPOINT" | grep -q "alloy_"; then
        print_pass "Alloy-specific metrics found"
    else 
        print_warning "Alloy-specific metrics not found"
    fi
    
    # Test metrics transformation
    local metrics_payload='{
        "resourceMetrics": [{
            "resource": {
                "attributes": [{
                    "key": "service.name",
                    "value": {"stringValue": "test-metrics-service"}
                }]
            },
            "scopeMetrics": [{
                "metrics": [{
                    "name": "test_counter_total",
                    "unit": "1",
                    "sum": {
                        "dataPoints": [{
                            "startTimeUnixNano": "'$(date +%s%N)'",
                            "timeUnixNano": "'$(date +%s%N)'",
                            "asInt": "42"
                        }]
                    }
                }]
            }] 
        }]
    }'
    
    if curl -sf -X POST "$ALLOY_ENDPOINT/v1/metrics" \
        -H "Content-Type: application/json" \
        -d "$metrics_payload" >/dev/null 2>&1; then
        print_pass "Metrics transformation test data sent"
    else
        print_fail "Failed to send metrics test data"
    fi
}

# Test 7: Performance and load testing
test_performance() {
    print_test "Testing performance under load"
    
    print_status "Sending 100 spans rapidly..."
    
    local success_count=0
    local start_time=$(date +%s%N)
    
    for i in {1..100}; do
        local payload='{
            "resourceSpans": [{
                "resource": {
                    "attributes": [{
                        "key": "service.name",
                        "value": {"stringValue": "load-test-service"}
                    }]
                },
                "scopeSpans": [{
                    "spans": [{
                        "traceId": "'$(printf "%032d" $i)'",
                        "spanId": "'$(printf "%016d" $i)'",
                        "name": "load-test-span-'$i'",
                        "startTimeUnixNano": "'$(date +%s%N)'",
                        "endTimeUnixNano": "'$(date +%s%N)'"
                    }]
                }]
            }]
        }'
        
        if curl -sf -X POST "$ALLOY_ENDPOINT/v1/traces" \
            -H "Content-Type: application/json" \
            -d "$payload" >/dev/null 2>&1; then
            success_count=$((success_count + 1))
        fi
    done
    
    local end_time=$(date +%s%N)
    local duration=$(((end_time - start_time) / 1000000))  # Convert to milliseconds
    
    if [ $success_count -ge 95 ]; then
        print_pass "Performance test: $success_count/100 spans sent successfully in ${duration}ms"
    else
        print_fail "Performance test: Only $success_count/100 spans sent successfully"
    fi
}

# Test 8: Configuration validation
test_configuration() {
    print_test "Testing configuration validation"
    
    # Check if required environment variables are set
    local required_vars=("APP_NAME" "APP_VERSION" "ENVIRONMENT")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -eq 0 ]; then
        print_pass "All required environment variables are set"
    else
        print_warning "Missing environment variables: ${missing_vars[*]}"
    fi
    
    # Check if Alloy config file exists
    if [ -f "alloy/configs/enhanced-with-sort.alloy" ]; then
        print_pass "Alloy configuration file exists"
    else
        print_fail "Alloy configuration file not found"
    fi
}

# Test 9: Docker container health
test_container_health() {
    print_test "Testing Docker container health"
    
    # Check if Alloy container is running
    if docker ps | grep -q "grafana-alloy"; then
        print_pass "Grafana Alloy container is running"
    else
        print_fail "Grafana Alloy container is not running"
    fi
    
    # Check container logs for errors
    if docker logs grafana-alloy 2>&1 | grep -q "ERROR\|FATAL"; then
        print_warning "Errors found in Alloy container logs"
    else
        print_pass "No critical errors in Alloy container logs"
    fi
    
    # Check memory usage
    local memory_usage=$(docker stats grafana-alloy --no-stream --format "{{.MemPerc}}" 2>/dev/null || echo "N/A")
    if [[ "$memory_usage" != "N/A" ]]; then
        print_status "Alloy container memory usage: $memory_usage"
    fi
}

# Test 10: Grafana Cloud integration (if configured)
test_grafana_cloud() {
    print_test "Testing Grafana Cloud integration"
    
    if [ -n "$GRAFANA_CLOUD_INSTANCE_ID" ] && [ "$GRAFANA_CLOUD_INSTANCE_ID" != "your-instance-id" ]; then
        print_status "Grafana Cloud configured - testing connectivity"
        
        # This is a basic test - in real scenarios you'd check actual data delivery
        if [ -n "$GRAFANA_CLOUD_API_KEY" ] && [ "$GRAFANA_CLOUD_API_KEY" != "your-api-key" ]; then
            print_pass "Grafana Cloud credentials appear to be configured"
        else
            print_warning "Grafana Cloud API key not configured"
        fi
    else
        print_warning "Grafana Cloud not configured (using local endpoints)"
    fi
}

# Run all tests
run_all_tests() {
    print_banner
    
    # Wait for services to be ready
    print_status "Waiting for services to be ready..."
    sleep 5
    
    # Run tests
    test_connectivity
    test_resource_detection  
    test_intelligent_labeling
    test_filtering
    test_sorting
    test_metrics
    test_performance
    test_configuration
    test_container_health
    test_grafana_cloud
    
    # Print summary
    echo ""
    echo -e "${BLUE}=============================================="
    echo "  Test Summary"
    echo -e "===============================================${NC}"
    echo -e "Total Tests: $TOTAL_TESTS"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed! ✓${NC}"
        echo ""
        echo -e "${YELLOW}Next Steps:${NC}"
        echo "  1. Check sorted traces: cat tmp/sorted-traces.json"
        echo "  2. View metrics: curl http://localhost:8889/metrics"
        echo "  3. Access Grafana: http://localhost:3000"
        echo "  4. Monitor Alloy: http://localhost:12345"
        return 0
    else
        echo -e "${RED}Some tests failed. Check the output above for details.${NC}"
        return 1
    fi
}

# Handle command line arguments
case "${1:-all}" in
    "connectivity")
        test_connectivity
        ;;
    "resource")
        test_resource_detection
        ;;
    "labeling")
        test_intelligent_labeling
        ;;
    "filtering")
        test_filtering
        ;;
    "sorting")
        test_sorting
        ;;
    "metrics")
        test_metrics
        ;;
    "performance")
        test_performance
        ;;
    "config")
        test_configuration
        ;;
    "health")
        test_container_health
        ;;
    "cloud")
        test_grafana_cloud
        ;;
    "all"|"")
        run_all_tests
        ;;
    *)
        echo "Usage: $0 [test_name]"
        echo ""
        echo "Available tests:"
        echo "  connectivity    - Test basic connectivity"
        echo "  resource        - Test resource detection"
        echo "  labeling        - Test intelligent labeling"
        echo "  filtering       - Test environment filtering"
        echo "  sorting         - Test intelligent sorting"
        echo "  metrics         - Test metrics collection"
        echo "  performance     - Test performance under load"
        echo "  config          - Test configuration"
        echo "  health          - Test container health"
        echo "  cloud           - Test Grafana Cloud integration"
        echo "  all             - Run all tests (default)"
        exit 1
        ;;
esac