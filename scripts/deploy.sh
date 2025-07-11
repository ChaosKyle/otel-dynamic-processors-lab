#!/bin/bash

# OpenTelemetry Docker Lab Deployment Script
# This script sets up the enhanced OTLP pipeline with Grafana Cloud integration

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
ENV_FILE="$PROJECT_DIR/.env"
COMPOSE_FILE="$PROJECT_DIR/docker-compose-enhanced.yaml"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  OpenTelemetry Docker Lab Enhanced Setup  ${NC}"
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
    
    # Check Docker Compose (V1 or V2)
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
    else
        print_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
    
    # OpenTelemetry Collector supports native environment variable expansion
    print_status "Using OpenTelemetry Collector native environment variable expansion"
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        exit 1
    fi
    
    print_status "Prerequisites check passed!"
}

# Function to validate environment variables
validate_env() {
    print_status "Validating environment configuration..."
    
    if [ ! -f "$ENV_FILE" ]; then
        print_error "Environment file not found: $ENV_FILE"
        exit 1
    fi
    
    # Source the environment file
    source "$ENV_FILE"
    
    # Check required variables for Grafana Cloud
    if [ "$GRAFANA_CLOUD_INSTANCE_ID" = "your-instance-id" ]; then
        print_warning "GRAFANA_CLOUD_INSTANCE_ID is set to default value"
        print_warning "Please update .env file with your actual Grafana Cloud credentials"
    fi
    
    if [ "$GRAFANA_CLOUD_API_KEY" = "your-api-key" ]; then
        print_warning "GRAFANA_CLOUD_API_KEY is set to default value"
        print_warning "Please update .env file with your actual Grafana Cloud credentials"
    fi
    
    print_status "Environment validation completed!"
}

# Function to create required directories
create_directories() {
    print_status "Creating required directories..."
    
    mkdir -p "$PROJECT_DIR/data"
    mkdir -p "$PROJECT_DIR/grafana/provisioning/dashboards"
    mkdir -p "$PROJECT_DIR/grafana/provisioning/datasources"
    
    print_status "Directories created successfully!"
}

# Function to validate config files exist
validate_config_files() {
    print_status "Validating configuration files..."
    
    # List of config files to check
    config_files=(
        "config/collector-config-enhanced.yaml"
        "config/processor-config-enhanced.yaml"
        "config/prometheus.yml"
    )
    
    for config_file in "${config_files[@]}"; do
        if [ ! -f "$PROJECT_DIR/$config_file" ]; then
            print_error "Config file not found: $config_file"
            exit 1
        fi
    done
    
    print_status "Configuration files validated successfully!"
}

# Function to create Prometheus configuration
create_prometheus_config() {
    print_status "Creating Prometheus configuration..."
    
    cat > "$PROJECT_DIR/config/prometheus.yml" << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['otel-collector-enhanced:8888']
        labels:
          service: 'otel-collector'
          environment: '${ENVIRONMENT}'
  
  - job_name: 'otel-processor'
    static_configs:
      - targets: ['otel-processor-enhanced:8889']
        labels:
          service: 'otel-processor'
          environment: '${ENVIRONMENT}'
EOF
    
    print_status "Prometheus configuration created!"
}

# Function to create Grafana datasource configuration
create_grafana_config() {
    print_status "Creating Grafana configuration..."
    
    cat > "$PROJECT_DIR/grafana/provisioning/datasources/datasources.yaml" << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus-local:9090
    isDefault: true
    editable: true
    
  - name: Grafana Cloud Prometheus
    type: prometheus
    access: proxy
    url: ${GRAFANA_CLOUD_PROMETHEUS_URL}
    basicAuth: true
    basicAuthUser: ${GRAFANA_CLOUD_INSTANCE_ID}
    secureJsonData:
      basicAuthPassword: ${GRAFANA_CLOUD_API_KEY}
    editable: true
EOF
    
    print_status "Grafana configuration created!"
}

# Function to deploy the stack
deploy_stack() {
    print_status "Deploying OpenTelemetry stack..."
    
    # Pull latest images
    print_status "Pulling latest Docker images..."
    $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" pull
    
    # Start the stack
    print_status "Starting services..."
    $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" up -d
    
    print_status "Stack deployment initiated!"
}

# Function to wait for services to be ready
wait_for_services() {
    print_status "Waiting for services to be ready..."
    
    # Wait for collector health check
    print_status "Waiting for collector to be healthy..."
    timeout=60
    while [ $timeout -gt 0 ]; do
        if $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" exec -T otel-collector curl -f http://localhost:13133/ &> /dev/null; then
            print_status "Collector is healthy!"
            break
        fi
        sleep 2
        timeout=$((timeout - 2))
    done
    
    if [ $timeout -eq 0 ]; then
        print_warning "Collector health check timeout"
    fi
    
    # Wait for processor health check
    print_status "Waiting for processor to be healthy..."
    timeout=60
    while [ $timeout -gt 0 ]; do
        if $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" exec -T otel-processor curl -f http://localhost:13133/ &> /dev/null; then
            print_status "Processor is healthy!"
            break
        fi
        sleep 2
        timeout=$((timeout - 2))
    done
    
    if [ $timeout -eq 0 ]; then
        print_warning "Processor health check timeout"
    fi
    
    print_status "Service readiness check completed!"
}

# Function to display access information
display_access_info() {
    print_status "Deployment completed successfully!"
    echo
    echo -e "${BLUE}Access Information:${NC}"
    echo -e "  📊 Grafana (Local):          http://localhost:3000 (admin/admin)"
    echo -e "  📈 Prometheus (Local):       http://localhost:9090"
    echo -e "  🔍 Collector zpages:         http://localhost:55680"
    echo -e "  🔍 Processor zpages:         http://localhost:55679"
    echo -e "  🏥 Collector Health:         http://localhost:13134"
    echo -e "  🏥 Processor Health:         http://localhost:13133"
    echo -e "  📊 Collector Metrics:        http://localhost:8888/metrics"
    echo -e "  📊 Processor Metrics:        http://localhost:8889/metrics"
    echo
    echo -e "${BLUE}Monitoring:${NC}"
    echo -e "  🔗 Grafana Cloud:            https://grafana.com"
    echo -e "  📊 Traces sent to Tempo:     ${GRAFANA_CLOUD_TEMPO_URL}"
    echo -e "  📈 Metrics sent to Prometheus: ${GRAFANA_CLOUD_PROMETHEUS_URL}"
    echo
    echo -e "${BLUE}Commands:${NC}"
    echo -e "  View logs:                   $DOCKER_COMPOSE_CMD -f $COMPOSE_FILE logs -f"
    echo -e "  Stop services:               $DOCKER_COMPOSE_CMD -f $COMPOSE_FILE down"
    echo -e "  Restart services:            $DOCKER_COMPOSE_CMD -f $COMPOSE_FILE restart"
    echo
}

# Function to show service status
show_status() {
    print_status "Current service status:"
    $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" ps
}

# Main execution function
main() {
    print_header
    
    case "${1:-deploy}" in
        "deploy")
            check_prerequisites
            validate_env
            create_directories
            validate_config_files
            create_prometheus_config
            create_grafana_config
            deploy_stack
            wait_for_services
            display_access_info
            show_status
            ;;
        "stop")
            print_status "Stopping services..."
            $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" down
            print_status "Services stopped!"
            ;;
        "restart")
            print_status "Restarting services..."
            $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" restart
            print_status "Services restarted!"
            ;;
        "logs")
            $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" logs -f
            ;;
        "status")
            show_status
            ;;
        "clean")
            print_status "Cleaning up..."
            $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" down -v
            docker system prune -f
            print_status "Cleanup completed!"
            ;;
        *)
            echo "Usage: $0 {deploy|stop|restart|logs|status|clean}"
            echo "  deploy  - Deploy the OpenTelemetry stack"
            echo "  stop    - Stop all services"
            echo "  restart - Restart all services"
            echo "  logs    - Follow service logs"
            echo "  status  - Show service status"
            echo "  clean   - Clean up everything"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"