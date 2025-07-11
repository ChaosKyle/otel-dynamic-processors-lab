# OpenTelemetry Dynamic Processors Tutorial

This hands-on tutorial walks you through understanding and implementing OpenTelemetry's dynamic processors step by step.

## 🎯 Learning Objectives

By the end of this tutorial, you will:
- Understand the difference between static and dynamic processing
- Know how to implement environment-based filtering
- Be able to create intelligent attribute enrichment
- Understand resource detection and its benefits
- Know how to optimize costs with smart sampling

## 📋 Prerequisites

- Docker and Docker Compose installed
- Basic understanding of OpenTelemetry concepts
- 15-20 minutes of time

## 🚀 Step 1: Understanding the Architecture

Let's start by examining the two-layer architecture:

```bash
# Clone and enter the project
git clone <this-repo>
cd otel-docker-lab

# Look at the basic configuration
cat config/collector-config.yaml
cat config/processor-config.yaml
```

### Key Concepts

1. **Collector Layer (Dumb)**: Simple ingestion and forwarding
2. **Processor Layer (Smart)**: Advanced logic and filtering
3. **Separation of Concerns**: Each layer has a specific purpose

## 🛠️ Step 2: Setting Up Your Environment

Create your configuration file:

```bash
# Copy the example environment file
cp .env.example .env

# Edit with your preferred editor
nano .env
```

For this tutorial, set:
```bash
ENVIRONMENT=production
APP_NAME=tutorial-app
APP_VERSION=1.0.0
LOG_LEVEL=info
```

## 🔄 Step 3: Running the Basic Pipeline

Start with the simple two-layer setup:

```bash
# Deploy the basic pipeline
./scripts/deploy.sh deploy

# Check that everything is running
./scripts/deploy.sh status

# Look at the logs
./scripts/deploy.sh logs
```

You should see:
- Collector receiving traces
- Processor filtering and forwarding
- Telemetry generators creating sample data

## 🔍 Step 4: Understanding Dynamic Filtering

The most powerful feature is environment-based filtering. Let's see it in action:

```bash
# Watch the processor logs
docker logs -f otel-processor

# In another terminal, check what's being filtered
curl http://localhost:8889/metrics | grep dropped
```

### What's Happening?

1. Three telemetry generators send traces:
   - `telemetrygen-prod` (environment=prod) → **PASSES** filter
   - `telemetrygen-dev` (environment=dev) → **FILTERED OUT**
   - `telemetrygen-staging` (environment=staging) → **PASSES** filter

2. The filter processor drops dev traces to save costs
3. Only prod and staging data reaches the final destination

## 🏷️ Step 5: Attribute Enrichment

Let's explore how processors add context:

```bash
# Look at the processor configuration
cat config/processor-config.yaml | grep -A 10 "attributes:"

# See the enhanced version for more examples
cat config/processor-config-enhanced.yaml | grep -A 20 "attributes:"
```

### Dynamic Attributes Added

- `processor.layer`: Identifies which layer processed the data
- `processed.at`: Timestamp of processing
- Resource detection attributes (host, OS, etc.)

## 📊 Step 6: Monitoring the Pipeline

Check the health and metrics:

```bash
# Health checks
curl http://localhost:13133/  # Processor health
curl http://localhost:13134/  # Collector health

# Metrics endpoints
curl http://localhost:8888/metrics  # Collector metrics
curl http://localhost:8889/metrics  # Processor metrics

# Run the test suite
./scripts/test-pipeline.sh
```

## 🎛️ Step 7: Experimenting with Configuration

Let's modify the processor to understand dynamic behavior:

### Experiment 1: Change Filter Rules

Edit `config/processor-config.yaml`:

```yaml
filter:
  error_mode: ignore
  traces:
    span:
      # Try different filters
      - 'resource.attributes["environment"] == "staging"'  # Block staging instead
      # - 'attributes["http.status_code"] == 200'          # Block successful requests
```

```bash
# Restart to apply changes
./scripts/deploy.sh restart

# Watch the effect
docker logs -f otel-processor
```

### Experiment 2: Add Custom Attributes

Add to the attributes processor:

```yaml
attributes:
  actions:
    - key: tutorial.step
      action: insert
      value: "step-7"
    - key: learner.progress
      action: insert
      value: "advanced"
```

### Experiment 3: Resource Detection

Switch to the enhanced configuration to see resource detection:

```bash
# Stop basic version
./scripts/deploy.sh stop

# Start enhanced version with resource detection
docker-compose -f docker-compose-enhanced.yaml up -d

# Watch for detected resources
docker logs -f otel-collector-enhanced | grep -i "resource"
```

## 🧪 Step 8: Testing Different Scenarios

### Scenario 1: High Volume Environment

```bash
# Edit docker-compose.yml to increase telemetry rate
# Change --rate=1 to --rate=10 for all generators

# Restart and observe batching behavior
./scripts/deploy.sh restart
curl http://localhost:8889/metrics | grep batch
```

### Scenario 2: Different Environments

```bash
# Change environment in .env
echo "ENVIRONMENT=dev" >> .env

# Restart and see how dev traces are filtered
./scripts/deploy.sh restart
```

## 🏗️ Step 9: Advanced Patterns

### Pattern 1: Service-Based Routing

Add this to your processor config:

```yaml
routing:
  from_attribute: "service.name"
  table:
    - value: "payment-service"
      exporters: ["otlp/payment-backend"]
    - value: "user-service"
      exporters: ["otlp/user-backend"]
  default_exporters: ["otlp/default"]
```

### Pattern 2: Sampling Based on Service Load

```yaml
probabilistic_sampler:
  hash_seed: 22
  sampling_percentage: 10  # 10% sampling for high-volume services
```

### Pattern 3: Metric Transformation

```yaml
metricstransform:
  transforms:
    - include: "http_request_duration"
      match_type: strict
      action: update
      operations:
        - action: add_label
          new_label: "environment"
          new_value: "${env:ENVIRONMENT}"
```

## 🎓 Step 10: Production Readiness

Before going to production, consider:

### 1. Resource Limits

```yaml
# In docker-compose.yml
services:
  otel-processor:
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '0.5'
```

### 2. Health Monitoring

```bash
# Set up health check monitoring
watch -n 5 'curl -s http://localhost:13133/ && echo "Processor OK" || echo "Processor DOWN"'
```

### 3. Error Handling

```yaml
# In processor config
processors:
  filter:
    error_mode: propagate  # Fail fast on errors in production
```

### 4. Security

```yaml
# Add authentication for production exporters
exporters:
  otlp/secure:
    endpoint: "https://your-backend.com:4317"
    headers:
      authorization: "Bearer ${env:API_TOKEN}"
    tls:
      insecure: false
```

## 🧹 Step 11: Cleanup

When you're done with the tutorial:

```bash
# Stop all services
./scripts/deploy.sh clean

# Remove test data
docker volume prune -f
```

## 🔄 What You've Learned

✅ **Dynamic Processing**: Processors that adapt to runtime conditions
✅ **Environment Filtering**: Cost optimization through intelligent data selection
✅ **Attribute Enrichment**: Adding context for better observability
✅ **Resource Detection**: Automatic infrastructure discovery
✅ **Pipeline Architecture**: Separation of ingestion and processing concerns
✅ **Monitoring**: Health checks and metrics for production readiness

## 🚀 Next Steps

1. **Explore Kubernetes**: Try the Helm deployment in `helm/`
2. **Grafana Integration**: Set up the enhanced stack with Grafana Cloud
3. **Custom Processors**: Write your own processor logic
4. **Production Deployment**: Implement in your real environment
5. **Advanced Use Cases**: Explore the examples in the main README

## 💡 Pro Tips

- Always test configuration changes in a development environment first
- Monitor processor metrics to understand data flow and performance
- Use the test script (`./scripts/test-pipeline.sh`) to validate changes
- Start simple and gradually add complexity
- Document your processor logic for team members

## 🆘 Troubleshooting

- **No data flowing**: Check receiver endpoints and network connectivity
- **High memory usage**: Adjust batch sizes and memory limits
- **Configuration errors**: Use `docker logs` to see startup errors
- **Performance issues**: Monitor metrics and adjust resource limits

Congratulations! You've completed the OpenTelemetry Dynamic Processors tutorial. You now understand how to build intelligent, cost-effective telemetry pipelines.