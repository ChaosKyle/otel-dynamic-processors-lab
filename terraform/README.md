# OpenTelemetry Dynamic Processors Terraform Infrastructure

This directory contains Terraform configurations to deploy a comprehensive OpenTelemetry dynamic processors stack with advanced filtering, AI-powered recommendations, and Grafana integration.

## 🏗️ Architecture

The Terraform setup deploys:

- **OpenTelemetry Collector**: Ingests telemetry data from applications
- **OpenTelemetry Processor**: Advanced filtering with comprehensive enforcement policies
- **Grafana Integration**: Dashboards, data sources, and alerts
- **Kubernetes Resources**: Deployments, services, configmaps, and RBAC
- **AI-Powered Features**: Grok recommendation engine for intelligent filtering

## 🚀 Quick Start

### Prerequisites

1. **Terraform** >= 1.0
2. **Kubernetes cluster** with kubectl configured
3. **Grafana Cloud account** with API credentials
4. **Grok API key** (optional, for AI features)

### 1. Initialize Terraform

```bash
cd terraform/
terraform init
```

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your configuration
```

### 3. Deploy the Stack

```bash
# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

### 4. Verify Deployment

```bash
# Check pod status
kubectl get pods -n otel-system

# View service endpoints
kubectl get svc -n otel-system

# Check collector logs
kubectl logs -n otel-system deployment/otel-collector

# Check processor logs
kubectl logs -n otel-system deployment/otel-processor
```

## 📋 Configuration

### Required Variables

```hcl
# Grafana Configuration
grafana_url                   = "https://your-grafana.grafana.net"
grafana_api_key              = "your-api-key"
grafana_cloud_instance_id    = "123456"
grafana_cloud_api_key        = "glc_your-cloud-key"
grafana_cloud_prometheus_url = "https://prometheus-url"
grafana_cloud_tempo_url      = "https://tempo-url"
grafana_cloud_loki_url       = "https://loki-url"
```

### Filter Processor Enforcement

The system includes comprehensive enforcement policies:

#### 🔒 Security Compliance
- Drops spans with security violations
- Removes sensitive headers and attributes
- Blocks unauthorized environments in production
- Filters health checks and debug traces

#### 💰 Cost Optimization
- Drops high-cardinality metrics (configurable threshold)
- Filters noisy spans (short duration internal spans)
- Samples low-priority spans at reduced rates
- Enforces data retention policies

#### 🛡️ PII Filtering
- Automatically detects and anonymizes email addresses
- Masks credit card numbers and SSNs
- Removes forbidden patterns from attributes
- Complies with privacy regulations

#### 📊 Label Policy Enforcement
- Requires specific labels on all telemetry data
- Validates environment values
- Enforces naming conventions
- Adds compliance metadata

### AI-Powered Features

When `enable_grok_processor = true`:

- **Intelligent Recommendations**: AI analyzes telemetry patterns
- **Automatic Filter Generation**: Creates OTel-compatible filter rules
- **Cost Analysis**: Identifies optimization opportunities
- **Security Analysis**: Detects potential security issues
- **Policy Enforcement**: Ensures compliance with governance policies

## 📊 Monitoring & Dashboards

### Created Dashboards

1. **OpenTelemetry Collector Overview**
   - Spans received vs sent
   - Memory usage and performance
   - Processing latency metrics

2. **Dynamic Processors Deep Dive**
   - Filter processor effectiveness
   - Compliance violations by type
   - PII filtering actions
   - Grok AI recommendations

### Metrics Endpoints

```bash
# Collector metrics
kubectl port-forward -n otel-system service/otel-collector-service 8888:8888
curl http://localhost:8888/metrics

# Processor metrics
kubectl port-forward -n otel-system service/otel-processor-service 8889:8889
curl http://localhost:8889/metrics
```

### Health Checks

```bash
# Collector health
kubectl port-forward -n otel-system service/otel-collector-service 13133:13133
curl http://localhost:13133

# Processor health
kubectl port-forward -n otel-system service/otel-processor-service 13134:13134
curl http://localhost:13134
```

## 🔧 Advanced Configuration

### Environment-Specific Settings

```hcl
# Development
environment = "dev"
enable_cost_optimization = false
log_level = "debug"
retention_days = 7

# Production
environment = "prod"
enable_cost_optimization = true
enable_security_compliance = true
enable_pii_filtering = true
log_level = "info"
retention_days = 90
```

### Custom Resource Limits

```hcl
collector_resources = {
  requests = {
    cpu    = "200m"
    memory = "256Mi"
  }
  limits = {
    cpu    = "1000m"
    memory = "1Gi"
  }
}

processor_resources = {
  requests = {
    cpu    = "500m"
    memory = "512Mi"
  }
  limits = {
    cpu    = "2000m"
    memory = "2Gi"
  }
}
```

### Scaling Configuration

```hcl
enable_autoscaling = true
min_replicas = 3
max_replicas = 20
target_cpu_utilization = 60
```

## 🔒 Security Features

### RBAC Configuration
- ServiceAccount with minimal required permissions
- ClusterRole for resource discovery
- Secure secret management for credentials

### Network Security
- TLS-encrypted communication where supported
- Internal-only service exposure
- Configurable ingress rules

### Data Protection
- Automatic PII detection and anonymization
- Sensitive data filtering
- Audit logging for compliance

## 🧪 Testing

### Validate Configuration

```bash
# Test OTLP endpoint
kubectl port-forward -n otel-system service/otel-collector-service 4317:4317

# Send test trace
curl -X POST http://localhost:4317/v1/traces \
  -H "Content-Type: application/x-protobuf" \
  --data-binary @test-trace.pb
```

### Monitor Filter Effectiveness

```bash
# Check filter metrics
curl -s http://localhost:8889/metrics | grep -E "(dropped|filtered)"

# View processor logs
kubectl logs -n otel-system deployment/otel-processor | grep -E "(dropped|filtered|violation)"
```

## 📚 Module Structure

```
terraform/
├── main.tf                    # Main configuration
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── grafana.tf                # Grafana resources
├── kubernetes.tf             # Kubernetes resources
├── terraform.tfvars.example  # Example variables
├── modules/
│   └── otel-stack/           # Reusable module
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── [submodules]/
└── templates/
    ├── enhanced-filter-processor.yaml.tpl
    ├── collector-config.yaml.tpl
    └── grok-policies.yaml.tpl
```

## 🛠️ Troubleshooting

### Common Issues

#### 1. Pods Not Starting
```bash
# Check pod status
kubectl describe pod -n otel-system [pod-name]

# Check resource limits
kubectl top pods -n otel-system
```

#### 2. Configuration Errors
```bash
# Validate collector config
kubectl get configmap -n otel-system otel-collector-config -o yaml

# Check processor config
kubectl get configmap -n otel-system otel-processor-config -o yaml
```

#### 3. Grafana Connection Issues
```bash
# Test Grafana API connectivity
curl -H "Authorization: Bearer $GRAFANA_API_KEY" \
  "$GRAFANA_URL/api/health"

# Verify data source configuration
curl -H "Authorization: Bearer $GRAFANA_API_KEY" \
  "$GRAFANA_URL/api/datasources"
```

#### 4. Filter Not Working
```bash
# Check filter processor metrics
kubectl port-forward -n otel-system service/otel-processor-service 8889:8889
curl -s http://localhost:8889/metrics | grep processor_dropped

# Enable debug logging
kubectl patch deployment -n otel-system otel-processor \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"otel-processor","env":[{"name":"LOG_LEVEL","value":"debug"}]}]}}}}'
```

### Debug Commands

```bash
# Full cluster status
kubectl get all -n otel-system

# Configuration validation
terraform validate
terraform plan -detailed-exitcode

# Resource usage
kubectl top pods -n otel-system
kubectl top nodes
```

## 🔄 Updates and Maintenance

### Updating the Stack

```bash
# Update Terraform configuration
git pull origin main

# Plan changes
terraform plan

# Apply updates
terraform apply
```

### Scaling Operations

```bash
# Manual scaling
kubectl scale deployment -n otel-system otel-collector --replicas=5
kubectl scale deployment -n otel-system otel-processor --replicas=5

# Update autoscaling
terraform apply -var="max_replicas=20"
```

### Configuration Updates

```bash
# Update ConfigMaps
terraform apply -target=kubernetes_config_map.otel_processor_config

# Restart deployments to pick up changes
kubectl rollout restart deployment -n otel-system otel-collector
kubectl rollout restart deployment -n otel-system otel-processor
```

## 📖 Additional Resources

- [OpenTelemetry Collector Documentation](https://opentelemetry.io/docs/collector/)
- [Grafana Provider Documentation](https://registry.terraform.io/providers/grafana/grafana/latest/docs)
- [Kubernetes Provider Documentation](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- [OTel Processor Reference](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test thoroughly
4. Submit a pull request with detailed description

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.