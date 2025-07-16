#!/bin/bash

# OpenTelemetry Sort Processor Deployment Script
# Quick deployment script for the sorting processor implementation

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
COMPOSE_FILE="$PROJECT_DIR/docker-compose-sort.yml"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[DEPLOY]${NC} $1"
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
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  OpenTelemetry Sort Processor Deployment  ${NC}"
    echo -e "${BLUE}============================================${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check Docker Compose
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
    else
        print_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        exit 1
    fi
    
    print_success "Prerequisites check passed!"
}

# Function to validate configuration
validate_configuration() {
    print_status "Validating configuration..."
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        print_error "Docker Compose file not found: $COMPOSE_FILE"
        exit 1
    fi
    
    # Run validation script
    if "$PROJECT_DIR/scripts/validate-sort-implementation.sh" > /dev/null 2>&1; then
        print_success "Configuration validation passed"
    else
        print_error "Configuration validation failed"
        exit 1
    fi
}

# Function to deploy the stack
deploy_stack() {
    print_status "Deploying OpenTelemetry Sort Processor stack..."
    
    # Pull latest images
    print_status "Pulling latest Docker images..."
    $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" pull
    
    # Create required directories
    mkdir -p "$PROJECT_DIR/tmp"
    mkdir -p "$PROJECT_DIR/test-data"
    mkdir -p "$PROJECT_DIR/test-results"
    
    # Start the stack
    print_status "Starting services..."
    $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" up -d
    
    print_success "Stack deployment initiated!"
}

# Function to wait for services to be ready
wait_for_services() {
    print_status "Waiting for services to be ready..."
    
    # Wait for collector health check
    print_status "Waiting for collector to be healthy..."
    local timeout=60
    while [ $timeout -gt 0 ]; do
        if curl -f http://localhost:13134/ &> /dev/null; then
            print_success "Collector is healthy!"
            break
        fi
        sleep 2
        timeout=$((timeout - 2))
    done
    
    if [ $timeout -eq 0 ]; then
        print_warning "Collector health check timeout"
    fi
    
    # Wait for processor health check
    print_status "Waiting for sort processor to be healthy..."
    timeout=60
    while [ $timeout -gt 0 ]; do
        if curl -f http://localhost:13133/ &> /dev/null; then
            print_success "Sort processor is healthy!"
            break
        fi
        sleep 2
        timeout=$((timeout - 2))
    done
    
    if [ $timeout -eq 0 ]; then
        print_warning "Sort processor health check timeout"
    fi
    
    print_success "Service readiness check completed!"
}

# Function to run initial tests
run_initial_tests() {
    print_status "Running initial tests..."
    
    # Wait a bit for telemetry to be generated
    sleep 10
    
    # Check if sorting is working
    if docker logs otel-processor-sort | grep -q "sort."; then
        print_success "Sorting processor is processing data with sort metadata"
    else
        print_warning "No sort metadata found in logs yet (this is normal for new deployments)"
    fi
    
    # Check metrics endpoints
    if curl -f http://localhost:8889/metrics &> /dev/null; then
        print_success "Sort processor metrics endpoint accessible"
    else
        print_warning "Sort processor metrics endpoint not accessible yet"
    fi
    
    print_success "Initial tests completed!"
}

# Function to display access information
display_access_info() {
    print_success "Deployment completed successfully!"
    echo
    echo -e "${BLUE}🔗 Access Information:${NC}"
    echo -e "  🏥 Collector Health:         http://localhost:13134"
    echo -e "  🏥 Sort Processor Health:    http://localhost:13133"
    echo -e "  📊 Collector Metrics:        http://localhost:8888/metrics"
    echo -e "  📊 Sort Processor Metrics:   http://localhost:8889/metrics"
    echo -e "  🔍 Collector zpages:         http://localhost:55680"
    echo -e "  🔍 Sort Processor zpages:    http://localhost:55679"
    echo -e "  📈 Prometheus (Local):       http://localhost:9090"
    echo -e "  📊 Grafana (Local):          http://localhost:3000 (admin/admin)"
    echo
    echo -e "${BLUE}🚀 Services Running:${NC}"
    echo -e "  📥 Collector Layer:          Ingests telemetry data"
    echo -e "  🔄 Sort Processor Layer:     Sorts and processes data"
    echo -e "  🎯 Payment Service:          High priority telemetry"
    echo -e "  👤 User Service:             Medium priority telemetry"
    echo -e "  📢 Notification Service:     Low priority telemetry"
    echo -e "  🧪 Dev Service:              Filtered out (dev environment)"
    echo
    echo -e "${BLUE}🧪 Testing Commands:${NC}"
    echo -e "  Run unit tests:              ./scripts/test-sort-processor.sh"
    echo -e "  Run benchmarks:              ./scripts/benchmark-sort-processor.sh"
    echo -e "  View logs:                   docker logs otel-processor-sort"
    echo -e "  View service status:         $DOCKER_COMPOSE_CMD -f $COMPOSE_FILE ps"
    echo -e "  Stop services:               $DOCKER_COMPOSE_CMD -f $COMPOSE_FILE down"
    echo
    echo -e "${BLUE}📋 Monitoring:${NC}"
    echo "  Check if sorting is working:"
    echo "    docker logs otel-processor-sort | grep 'sort.'"
    echo "  View processing metrics:"
    echo "    curl http://localhost:8889/metrics | grep otelcol"
    echo "  Monitor service health:"
    echo "    watch 'curl -s http://localhost:13133/ && echo \"✅ Healthy\" || echo \"❌ Unhealthy\"'"
    echo
}

# Function to show service status
show_status() {
    print_status "Current service status:"
    $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" ps
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  deploy      Deploy the sort processor stack (default)"
    echo "  status      Show service status"
    echo "  logs        Show service logs"
    echo "  stop        Stop all services"
    echo "  restart     Restart all services"
    echo "  test        Run tests after deployment"
    echo "  help        Show this help message"
    echo
    echo "Examples:"
    echo "  $0                    # Deploy the stack"
    echo "  $0 deploy             # Deploy the stack"
    echo "  $0 status             # Show service status"
    echo "  $0 logs               # Show service logs"
    echo "  $0 test               # Run tests"
}

# Main execution function
main() {
    print_header
    
    case "${1:-deploy}" in
        "deploy")
            check_prerequisites
            validate_configuration
            deploy_stack
            wait_for_services
            run_initial_tests
            display_access_info
            show_status
            ;;
        "status")
            show_status
            ;;
        "logs")
            $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" logs -f
            ;;
        "stop")
            print_status "Stopping services..."
            $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" down
            print_success "Services stopped!"
            ;;
        "restart")
            print_status "Restarting services..."
            $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" restart
            print_success "Services restarted!"
            ;;
        "test")
            print_status "Running tests..."
            "$PROJECT_DIR/scripts/test-sort-processor.sh"
            ;;
        "help")
            show_usage
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