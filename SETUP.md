# OpenTelemetry Docker Lab - Enhanced Setup Guide

## Overview

This enhanced setup provides a production-ready OpenTelemetry pipeline with:
- **Advanced Label Strategy**: Automatic resource detection and custom labeling
- **Grafana Cloud Integration**: Direct export to Grafana Cloud for Traces and Metrics
- **Environment-based Filtering**: Smart filtering based on environment labels
- **Comprehensive Monitoring**: Local Prometheus and Grafana setup
- **Automated Deployment**: Script-based deployment with variable substitution

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Applications   │───▶│  Collector      │───▶│  Processor      │
│  (telemetrygen) │    │  (Ingestion)    │    │  (Smart Layer)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
                                            ┌─────────────────┐
                                            │  Grafana Cloud  │
                                            │  - Tempo        │
                                            │  - Prometheus   │
                                            └─────────────────┘
```

## Key Features

### 🏷️ Label Strategy
- **Resource Detection**: Automatically detects Docker, system, and process metadata
- **Custom Labeling**: Adds service metadata, environment info, and Grafana Cloud tags
- **Attribute Transformation**: Normalizes and enriches telemetry data
- **Smart Filtering**: Environment-based filtering (dev traces are dropped)

### 🌐 Grafana Cloud Integration
- **Tempo Export**: Traces sent directly to Grafana Cloud Tempo
- **Prometheus Export**: Metrics sent to Grafana Cloud Prometheus
- **Proper Authentication**: Uses Instance ID and API key for secure access
- **Retry Logic**: Built-in retry and queue mechanisms for reliability

### 📊 Monitoring Stack
- **Local Prometheus**: Scrapes collector metrics
- **Local Grafana**: Pre-configured dashboards and datasources
- **Health Checks**: Built-in health monitoring for all services
- **Performance Metrics**: Comprehensive pipeline performance monitoring

## Prerequisites

- Docker Desktop installed and running
- Grafana Cloud account (free tier available)
- Basic understanding of OpenTelemetry concepts

## Quick Start

### 1. Configure Grafana Cloud

First, get your Grafana Cloud credentials:

1. Go to [Grafana Cloud](https://grafana.com/products/cloud/)
2. Create an account or log in
3. Navigate to "My Account" → "API Keys"
4. Create a new API key with "MetricsPublisher" role
5. Note down your:
   - Instance ID (usually a number)
   - API Key
   - Prometheus URL
   - Tempo URL

### 2. Update Environment Variables

Edit the `.env` file with your actual values:

```bash
# Replace with your actual Grafana Cloud credentials
GRAFANA_CLOUD_INSTANCE_ID=123456
GRAFANA_CLOUD_API_KEY=your-actual-api-key
GRAFANA_CLOUD_PROMETHEUS_URL=https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push
GRAFANA_CLOUD_TEMPO_URL=https://tempo-prod-04-eu-west-0.grafana.net:443

# Customize your application settings
APP_NAME=my-otel-app
APP_VERSION=2.0.0
ENVIRONMENT=production
SERVICE_NAMESPACE=my-namespace
CLUSTER_NAME=local-cluster
REGION=us-east-1
```

### 3. Deploy the Stack

```bash
# Make the script executable (if not already)
chmod +x deploy.sh

# Deploy the enhanced stack
./deploy.sh deploy
```

### 4. Access the Dashboards

After deployment, access these URLs:

- **Grafana Local**: http://localhost:3000 (admin/admin)
- **Prometheus Local**: http://localhost:9090
- **Collector Health**: http://localhost:13134
- **Processor Health**: http://localhost:13133
- **Collector Metrics**: http://localhost:8888/metrics
- **Processor Metrics**: http://localhost:8889/metrics

## Advanced Configuration

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `GRAFANA_CLOUD_INSTANCE_ID` | Your Grafana Cloud instance ID | `123456` |
| `GRAFANA_CLOUD_API_KEY` | Your Grafana Cloud API key | `glc_xxx` |
| `GRAFANA_CLOUD_PROMETHEUS_URL` | Prometheus remote write URL | `https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push` |
| `GRAFANA_CLOUD_TEMPO_URL` | Tempo OTLP endpoint | `https://tempo-prod-04-eu-west-0.grafana.net:443` |
| `APP_NAME` | Your application name | `my-service` |
| `APP_VERSION` | Application version | `1.0.0` |
| `ENVIRONMENT` | Deployment environment | `production` |
| `SERVICE_NAMESPACE` | Service namespace | `payments` |
| `CLUSTER_NAME` | Cluster name | `prod-cluster` |
| `REGION` | Cloud region | `us-west-2` |
| `METRICS_SCRAPE_INTERVAL` | Prometheus scrape interval | `15s` |
| `TRACES_SAMPLING_RATE` | Trace sampling rate (0-100) | `1.0` |
| `LOGS_LEVEL` | Log level | `info` |

### Label Strategy Configuration

The pipeline automatically adds these labels to all telemetry:

**Resource Attributes:**
- `service.name` - Application name
- `service.version` - Application version
- `service.namespace` - Service namespace
- `deployment.environment` - Environment (prod/staging/dev)
- `k8s.cluster.name` - Cluster name
- `cloud.region` - Cloud region
- `host.name` - Hostname
- `os.type` - Operating system
- `process.pid` - Process ID

**Custom Grafana Labels:**
- `grafana.service.name` - Service name for Grafana
- `grafana.environment` - Environment for Grafana
- `grafana.cluster` - Cluster for Grafana
- `grafana.region` - Region for Grafana
- `grafana.cloud.instance` - Grafana Cloud instance ID

### Filtering Strategy

The processor filters out traces based on:
- `resource.attributes["environment"] == "dev"`
- `resource.attributes["deployment.environment"] == "dev"`

This means only `prod` and `staging` traces reach Grafana Cloud.

## Monitoring and Troubleshooting

### Health Checks

Check service health:
```bash
# Collector health
curl http://localhost:13134/

# Processor health
curl http://localhost:13133/
```

### View Logs

```bash
# View all logs
./deploy.sh logs

# View specific service logs
docker-compose -f docker-compose-enhanced.yaml logs -f otel-processor
```

### Metrics Endpoints

- **Collector Metrics**: http://localhost:8888/metrics
- **Processor Metrics**: http://localhost:8889/metrics
- **Prometheus**: http://localhost:9090

### Common Issues

1. **Grafana Cloud Authentication Failed**
   - Check your Instance ID and API key
   - Verify the Prometheus and Tempo URLs are correct
   - Ensure your API key has the right permissions

2. **Services Not Starting**
   - Check Docker is running
   - Verify port availability
   - Review logs with `./deploy.sh logs`

3. **No Data in Grafana Cloud**
   - Check processor logs for export errors
   - Verify authentication credentials
   - Ensure traces are not being filtered out

## Commands

```bash
# Deploy the stack
./deploy.sh deploy

# Stop services
./deploy.sh stop

# Restart services
./deploy.sh restart

# View logs
./deploy.sh logs

# Check status
./deploy.sh status

# Clean up everything
./deploy.sh clean
```

## Data Flow

1. **Generation**: Three telemetrygen instances create traces with different environment labels
2. **Ingestion**: Collector receives traces and adds resource detection labels
3. **Processing**: Processor filters dev traces and adds Grafana-specific labels
4. **Export**: Traces go to Grafana Cloud Tempo, metrics to Grafana Cloud Prometheus
5. **Monitoring**: Local Prometheus and Grafana provide pipeline observability

## Performance Tuning

### Batch Processing
- `send_batch_size`: Number of spans per batch
- `timeout`: Maximum time to wait before sending
- `send_batch_max_size`: Maximum batch size

### Memory Management
- `memory_limiter`: Prevents OOM issues
- `limit_mib`: Soft memory limit
- `spike_limit_mib`: Hard memory limit

### Retry Configuration
- `initial_interval`: Initial retry delay
- `max_interval`: Maximum retry delay
- `max_elapsed_time`: Total retry timeout

## Security Considerations

- API keys are stored in environment variables
- TLS is enabled for Grafana Cloud connections
- Local services use HTTP (for development only)
- Consider using secrets management for production

## Next Steps

1. **Custom Instrumentation**: Add OpenTelemetry SDK to your applications
2. **Service Mesh**: Integrate with Istio or Linkerd
3. **Kubernetes**: Deploy to Kubernetes with proper RBAC
4. **Alerting**: Set up alerts in Grafana Cloud
5. **Cost Optimization**: Implement intelligent sampling strategies

## Support

For issues and questions:
- Check the [OpenTelemetry documentation](https://opentelemetry.io/docs/)
- Review [Grafana Cloud documentation](https://grafana.com/docs/grafana-cloud/)
- Check service logs with `./deploy.sh logs`