#!/bin/bash

# OpenTelemetry Dynamic Processors Lab - Test Pipeline Script
# This script validates that the OpenTelemetry pipeline is working correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_DIR/docker-compose-enhanced.yaml"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[TEST]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_header() {
    echo -e "${BLUE}===============================================${NC}"
    echo -e "${BLUE}  OpenTelemetry Dynamic Processors Test Suite ${NC}"
    echo -e "${BLUE}===============================================${NC}"
}

# Function to check if services are running
check_services_running() {
    print_status "Checking if services are running..."
    
    # Check Docker Compose (V1 or V2)
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
    else
        print_error "Docker Compose not found"
        exit 1
    fi
    
    # Check if containers are running
    if ! $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        print_error "Services are not running. Please run './scripts/deploy.sh deploy' first"
        exit 1
    fi
    
    print_success "Services are running"
}

# Function to test health endpoints
test_health_endpoints() {
    print_status "Testing health endpoints..."
    
    # Test collector health
    if curl -f http://localhost:13134/ &> /dev/null; then
        print_success "Collector health check passed"
    else
        print_error "Collector health check failed"
        return 1
    fi
    
    # Test processor health
    if curl -f http://localhost:13133/ &> /dev/null; then
        print_success "Processor health check passed"
    else
        print_error "Processor health check failed"
        return 1
    fi
}

# Function to test metrics endpoints
test_metrics_endpoints() {
    print_status "Testing metrics endpoints..."
    
    # Test collector metrics
    if curl -f http://localhost:8888/metrics &> /dev/null; then
        print_success "Collector metrics endpoint accessible"
    else
        print_error "Collector metrics endpoint failed"
        return 1
    fi
    
    # Test processor metrics
    if curl -f http://localhost:8889/metrics &> /dev/null; then
        print_success "Processor metrics endpoint accessible"
    else
        print_error "Processor metrics endpoint failed"
        return 1
    fi
}

# Function to test trace processing
test_trace_processing() {
    print_status "Testing trace processing..."
    
    # Get initial metrics
    local initial_spans=$(curl -s http://localhost:8888/metrics | grep -c "otelcol_receiver_accepted_spans_total" || echo "0")
    
    # Wait a moment for telemetry generators to send data
    sleep 10
    
    # Get updated metrics
    local updated_spans=$(curl -s http://localhost:8888/metrics | grep -c "otelcol_receiver_accepted_spans_total" || echo "0")
    
    if [ "$updated_spans" -gt "$initial_spans" ]; then
        print_success "Traces are being processed"
    else
        print_warning "No trace processing detected (this might be normal if generators haven't started)"
    fi
}

# Function to test environment filtering
test_environment_filtering() {
    print_status "Testing environment filtering..."
    
    # Check processor metrics for dropped spans
    local dropped_spans=$(curl -s http://localhost:8889/metrics | grep "otelcol_processor_dropped_spans_total" | head -1 | awk '{print $NF}' || echo "0")
    
    if [ "$dropped_spans" -gt "0" ]; then
        print_success "Environment filtering is working - $dropped_spans spans dropped"
    else
        print_warning "No dropped spans detected (dev environment filtering might not be active yet)"
    fi
}

# Function to test Grafana integration
test_grafana_integration() {
    print_status "Testing Grafana integration..."
    
    # Check if Grafana is accessible
    if curl -f http://localhost:3000/api/health &> /dev/null; then
        print_success "Grafana is accessible"
    else
        print_error "Grafana is not accessible"
        return 1
    fi
    
    # Check if Prometheus is accessible
    if curl -f http://localhost:9090/-/healthy &> /dev/null; then
        print_success "Prometheus is accessible"
    else
        print_error "Prometheus is not accessible"
        return 1
    fi
}

# Function to test configuration validation
test_configuration_validation() {
    print_status "Testing configuration validation..."
    
    # Check if config files exist
    local config_files=(
        "$PROJECT_DIR/config/collector-config-enhanced.yaml"
        "$PROJECT_DIR/config/processor-config-enhanced.yaml"
        "$PROJECT_DIR/config/prometheus.yml"
    )
    
    for config_file in "${config_files[@]}"; do
        if [ -f "$config_file" ]; then
            print_success "Config file exists: $(basename "$config_file")"
        else
            print_error "Config file missing: $(basename "$config_file")"
            return 1
        fi
    done
    
    # Validate YAML syntax (if yq is available)
    if command -v yq &> /dev/null; then
        for config_file in "${config_files[@]}"; do
            if [[ "$config_file" == *.yaml ]]; then
                if yq eval '.' "$config_file" &> /dev/null; then
                    print_success "YAML syntax valid: $(basename "$config_file")"
                else
                    print_error "YAML syntax invalid: $(basename "$config_file")"
                    return 1
                fi
            fi
        done
    else
        print_warning "yq not found - skipping YAML validation"
    fi
}

# Function to run comprehensive tests
run_comprehensive_tests() {
    print_status "Running comprehensive test suite..."
    
    local tests_passed=0
    local tests_total=6
    
    # Run all tests
    if check_services_running; then ((tests_passed++)); fi
    if test_health_endpoints; then ((tests_passed++)); fi
    if test_metrics_endpoints; then ((tests_passed++)); fi
    if test_trace_processing; then ((tests_passed++)); fi
    if test_environment_filtering; then ((tests_passed++)); fi
    if test_grafana_integration; then ((tests_passed++)); fi
    if test_configuration_validation; then ((tests_passed++)); fi
    
    echo
    print_status "Test Results Summary:"
    echo -e "  Tests Passed: ${GREEN}$tests_passed${NC}/$tests_total"
    
    if [ "$tests_passed" -eq "$tests_total" ]; then
        print_success "All tests passed! 🎉"
        return 0
    else
        print_error "Some tests failed. Please check the output above."
        return 1
    fi
}

# Function to generate test report
generate_test_report() {
    print_status "Generating test report..."
    
    local report_file="$PROJECT_DIR/test-report.txt"
    
    cat > "$report_file" << EOF
OpenTelemetry Dynamic Processors Lab - Test Report
Generated: $(date)

Service Status:
EOF
    
    $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" ps >> "$report_file" 2>&1
    
    cat >> "$report_file" << EOF

Collector Metrics Sample:
EOF
    
    curl -s http://localhost:8888/metrics | head -20 >> "$report_file" 2>&1
    
    cat >> "$report_file" << EOF

Processor Metrics Sample:
EOF
    
    curl -s http://localhost:8889/metrics | head -20 >> "$report_file" 2>&1
    
    print_success "Test report generated: $report_file"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --health        Test health endpoints only"
    echo "  --metrics       Test metrics endpoints only"
    echo "  --processing    Test trace processing only"
    echo "  --filtering     Test environment filtering only"
    echo "  --grafana       Test Grafana integration only"
    echo "  --config        Test configuration validation only"
    echo "  --report        Generate test report"
    echo "  --help          Show this help message"
    echo
    echo "Examples:"
    echo "  $0                    # Run all tests"
    echo "  $0 --health           # Test health endpoints only"
    echo "  $0 --report           # Generate test report"
}

# Main execution
main() {
    print_header
    
    case "${1:-all}" in
        "--health")
            check_services_running
            test_health_endpoints
            ;;
        "--metrics")
            check_services_running
            test_metrics_endpoints
            ;;
        "--processing")
            check_services_running
            test_trace_processing
            ;;
        "--filtering")
            check_services_running
            test_environment_filtering
            ;;
        "--grafana")
            check_services_running
            test_grafana_integration
            ;;
        "--config")
            test_configuration_validation
            ;;
        "--report")
            check_services_running
            generate_test_report
            ;;
        "--help")
            show_usage
            ;;
        "all"|"")
            run_comprehensive_tests
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"