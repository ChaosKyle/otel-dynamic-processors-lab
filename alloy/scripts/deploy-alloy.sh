#!/bin/bash

# Deploy Grafana Alloy Version of OpenTelemetry Dynamic Processors Lab
# This script provides the same functionality as the original deploy.sh but for Alloy

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
ALLOY_CONFIG="enhanced-with-sort"
COMPOSE_FILE="alloy-docker-compose.yml"

print_banner() {
    echo -e "${BLUE}"
    echo "=============================================="
    echo "  Grafana Alloy Dynamic Processors Lab"
    echo "=============================================="
    echo -e "${NC}"
}

print_status() {
    echo -e "${GREEN}[STATUS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    print_status "Checking dependencies..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not available. Please install Docker Compose."
        exit 1
    fi
    
    # Check if .env file exists
    if [ ! -f .env ]; then
        print_warning ".env file not found. Creating from template..."
        create_env_template
    fi
    
    print_status "Dependencies check completed ✓"
}

create_env_template() {
    cat > .env << EOF
# Grafana Cloud Configuration
GRAFANA_CLOUD_INSTANCE_ID=your-instance-id
GRAFANA_CLOUD_API_KEY=your-api-key
GRAFANA_CLOUD_PROMETHEUS_URL=https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push
GRAFANA_CLOUD_TEMPO_URL=https://tempo-prod-04-eu-west-0.grafana.net:443
GRAFANA_CLOUD_LOKI_URL=https://logs-prod-006.grafana.net/loki/api/v1/push

# Application Configuration
APP_NAME=alloy-otel-lab
APP_VERSION=1.0.0
ENVIRONMENT=development
SERVICE_NAMESPACE=alloy-monitoring
CLUSTER_NAME=local-alloy-cluster
REGION=us-west-2

# Monitoring Configuration
METRICS_SCRAPE_INTERVAL=15s
TRACES_SAMPLING_RATE=1.0
LOG_LEVEL=info

# Resource Detection
ENABLE_RESOURCE_DETECTION=true
DETECT_DOCKER=true
DETECT_SYSTEM=true
DETECT_PROCESS=true
EOF
    
    print_warning "Please update the .env file with your Grafana Cloud credentials before proceeding."
}

validate_config() {
    print_status "Validating Alloy configuration..."
    
    local config_file="alloy/configs/${ALLOY_CONFIG}.alloy"
    
    if [ ! -f "$config_file" ]; then
        print_error "Alloy configuration file not found: $config_file"
        print_status "Available configurations:"
        ls alloy/configs/*.alloy 2>/dev/null || print_error "No Alloy configurations found"
        exit 1
    fi
    
    # TODO: Add Alloy config validation when alloy binary is available
    # alloy fmt --verify "$config_file"
    
    print_status "Configuration validation completed ✓"
}

deploy() {
    print_status "Deploying Grafana Alloy stack..."
    
    # Create necessary directories
    mkdir -p tmp
    mkdir -p logs
    
    # Start the stack
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "$COMPOSE_FILE" up -d
    else
        docker compose -f "$COMPOSE_FILE" up -d
    fi
    
    print_status "Waiting for services to start..."
    sleep 10
    
    # Check service health
    check_services
    
    print_status "Deployment completed successfully ✓"
    print_access_info
}

check_services() {
    print_status "Checking service health..."
    
    local services=(
        "grafana-alloy:12345:Alloy HTTP Server"
        "grafana-alloy:13133:Health Check"
        "grafana-alloy:4317:OTLP gRPC"
        "grafana-alloy:4318:OTLP HTTP"
        "prometheus-local:9090:Prometheus"
        "grafana-local:3000:Grafana"
    )
    
    for service in "${services[@]}"; do
        IFS=':' read -r container port name <<< "$service"
        
        if curl -sf "http://localhost:$port" >/dev/null 2>&1 || curl -sf "http://localhost:$port/health" >/dev/null 2>&1; then
            print_status "$name ✓"
        else
            print_warning "$name - not ready yet"
        fi
    done
}

print_access_info() {
    echo -e "${BLUE}"
    echo "=============================================="
    echo "  Access Information"
    echo "=============================================="
    echo -e "${NC}"
    echo "🔍 Grafana Alloy UI:     http://localhost:12345"
    echo "📊 Grafana Dashboard:    http://localhost:3000 (admin/admin)"
    echo "📈 Prometheus:           http://localhost:9090"
    echo "🏥 Health Check:         http://localhost:13133"
    echo "📋 Alloy Metrics:        http://localhost:8889/metrics"
    echo "🔍 zPages:               http://localhost:55679"
    echo ""
    echo -e "${YELLOW}Grafana Cloud Integration:${NC}"
    echo "  - Traces sent to: ${GRAFANA_CLOUD_TEMPO_URL:-Not configured}"
    echo "  - Metrics sent to: ${GRAFANA_CLOUD_PROMETHEUS_URL:-Not configured}"
    echo "  - Logs sent to: ${GRAFANA_CLOUD_LOKI_URL:-Not configured}"
    echo ""
    echo -e "${GREEN}Next Steps:${NC}"
    echo "  1. Configure your .env file with Grafana Cloud credentials"
    echo "  2. Run: $0 restart"
    echo "  3. View telemetry data in your Grafana Cloud instance"
    echo "  4. Run tests: ./alloy/scripts/test-alloy.sh"
}

status() {
    print_status "Checking Alloy stack status..."
    
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "$COMPOSE_FILE" ps
    else
        docker compose -f "$COMPOSE_FILE" ps
    fi
    
    echo ""
    check_services
}

logs() {
    local service="${1:-grafana-alloy}"
    
    print_status "Showing logs for $service..."
    
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "$COMPOSE_FILE" logs -f "$service"
    else
        docker compose -f "$COMPOSE_FILE" logs -f "$service"
    fi
}

stop() {
    print_status "Stopping Alloy stack..."
    
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "$COMPOSE_FILE" down
    else
        docker compose -f "$COMPOSE_FILE" down
    fi
    
    print_status "Stack stopped ✓"
}

restart() {
    print_status "Restarting Alloy stack..."
    stop
    sleep 5
    deploy
}

cleanup() {
    print_status "Cleaning up Alloy stack (removing volumes)..."
    
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "$COMPOSE_FILE" down -v
    else
        docker compose -f "$COMPOSE_FILE" down -v
    fi
    
    # Clean up temporary files
    rm -rf tmp/*
    rm -rf logs/*
    
    print_status "Cleanup completed ✓"
}

test_alloy() {
    print_status "Running Alloy tests..."
    
    # Test OTLP endpoint
    if curl -sf -X POST "http://localhost:4318/v1/traces" \
        -H "Content-Type: application/json" \
        -d '{"resourceSpans": []}' >/dev/null 2>&1; then
        print_status "OTLP HTTP endpoint ✓"
    else
        print_error "OTLP HTTP endpoint not responding"
    fi
    
    # Test health endpoint
    if curl -sf "http://localhost:13133" >/dev/null 2>&1; then
        print_status "Health check endpoint ✓"
    else
        print_error "Health check endpoint not responding"
    fi
    
    # Test metrics endpoint
    if curl -sf "http://localhost:8889/metrics" >/dev/null 2>&1; then
        print_status "Metrics endpoint ✓"
    else
        print_error "Metrics endpoint not responding"
    fi
    
    print_status "Basic tests completed"
}

show_help() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  deploy      Deploy the Alloy stack"
    echo "  status      Show stack status"
    echo "  logs        Show logs (default: alloy service)"
    echo "  stop        Stop the stack"
    echo "  restart     Restart the stack"
    echo "  cleanup     Stop and remove volumes"
    echo "  test        Run basic connectivity tests"
    echo "  help        Show this help message"
    echo ""
    echo "Options:"
    echo "  --config    Alloy configuration to use (default: enhanced-with-sort)"
    echo "  --compose   Docker Compose file to use (default: alloy-docker-compose.yml)"
    echo ""
    echo "Examples:"
    echo "  $0 deploy"
    echo "  $0 logs grafana-alloy"
    echo "  $0 deploy --config basic-template"
    echo "  $0 status"
    echo "  $0 test"
}

# Parse command line arguments
COMMAND="$1"
shift || true

while [[ $# -gt 0 ]]; do
    case $1 in
        --config)
            ALLOY_CONFIG="$2"
            shift 2
            ;;
        --compose)
            COMPOSE_FILE="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
print_banner

case "$COMMAND" in
    deploy)
        check_dependencies
        validate_config
        deploy
        ;;
    status)
        status
        ;;
    logs)
        logs "$1"
        ;;
    stop)
        stop
        ;;
    restart)
        check_dependencies
        validate_config
        restart
        ;;
    cleanup)
        cleanup
        ;;
    test)
        test_alloy
        ;;
    help|--help)
        show_help
        ;;
    "")
        print_error "No command specified"
        show_help
        exit 1
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac