# OpenTelemetry Dynamic Processors Helm Chart

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/otel-dynamic-processors)](https://artifacthub.io/packages/search?repo=otel-dynamic-processors)
[![Helm Version](https://img.shields.io/badge/helm-v3.0%2B-blue)](https://helm.sh/docs/intro/install/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive Helm chart for deploying OpenTelemetry's dynamic processors with advanced resource detection, intelligent labeling, and seamless Grafana Cloud integration.

## Features

- 🔄 **Two-tier Architecture**: Separate ingestion and processing layers
- 🏷️ **Dynamic Resource Detection**: Automatic Kubernetes resource discovery
- 🎯 **Smart Filtering**: Environment-based data filtering
- 📊 **Grafana Cloud Integration**: Direct export to Tempo and Prometheus
- 🔧 **Production Ready**: RBAC, security contexts, and monitoring
- 📈 **Auto-scaling**: HPA support for dynamic scaling
- 🛡️ **Security**: Pod security standards and network policies

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Prometheus Operator (for ServiceMonitor)
- Grafana Cloud account (optional)

## Installation

### Add the Helm Repository

```bash
helm repo add otel-dynamic-processors https://chaoskyle.github.io/otel-dynamic-processors-lab
helm repo update
```

### Quick Start

```bash
# Basic installation
helm install otel-processors otel-dynamic-processors/otel-dynamic-processors

# With Grafana Cloud integration
helm install otel-processors otel-dynamic-processors/otel-dynamic-processors \
  --set grafanaCloud.enabled=true \
  --set grafanaCloud.tempo.enabled=true \
  --set grafanaCloud.prometheus.enabled=true \
  --set grafanaCloud.tempo.endpoint="https://tempo-prod-04-eu-west-0.grafana.net:443" \
  --set grafanaCloud.prometheus.endpoint="https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push"
```

### Full Production Setup

```bash
# Create namespace
kubectl create namespace otel-system

# Create Grafana Cloud secret
kubectl create secret generic grafana-cloud-auth \
  --namespace otel-system \
  --from-literal=instanceId="123456" \
  --from-literal=apiKey="your-api-key"

# Install with custom values
helm install otel-processors otel-dynamic-processors/otel-dynamic-processors \
  --namespace otel-system \
  --values values-production.yaml
```

## Configuration

### Basic Configuration

```yaml
# values.yaml
application:
  name: "my-app"
  version: "1.0.0"
  environment: "production"
  cluster: "prod-cluster"
  region: "us-west-2"

collector:
  replicaCount: 3
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi

processor:
  replicaCount: 2
  resources:
    requests:
      cpu: 1000m
      memory: 2Gi
    limits:
      cpu: 2000m
      memory: 4Gi
```

### Grafana Cloud Integration

```yaml
# values.yaml
grafanaCloud:
  enabled: true
  tempo:
    enabled: true
    endpoint: "https://tempo-prod-04-eu-west-0.grafana.net:443"
    auth:
      existingSecret: "grafana-cloud-auth"
      instanceIdKey: "instanceId"
      apiKeyKey: "apiKey"
  
  prometheus:
    enabled: true
    endpoint: "https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push"
    auth:
      existingSecret: "grafana-cloud-auth"
      instanceIdKey: "instanceId"
      apiKeyKey: "apiKey"
    externalLabels:
      cluster: "prod-cluster"
      environment: "production"
```

### Advanced Filtering

```yaml
# values.yaml
processor:
  config:
    filtering:
      excludeEnvironments:
        - dev
        - test
        - staging
      excludeServices:
        - internal-health-check
        - debug-service
      excludeUrlPatterns:
        - ".*/health.*"
        - ".*/metrics.*"
        - ".*/debug.*"
```

### Resource Detection

```yaml
# values.yaml
collector:
  config:
    resourceDetection:
      detectors:
        - k8s_node
        - k8s_pod
        - system
        - process
        - env
      k8s_pod:
        auth_type: serviceAccount
        extract:
          metadata: [name, namespace, uid, start_time]
          annotations:
            - key: "*"
              from: pod
          labels:
            - key: "*"
              from: pod
```

## Examples

### Development Environment

```yaml
# values-dev.yaml
application:
  environment: "development"

collector:
  replicaCount: 1
  resources:
    requests:
      cpu: 100m
      memory: 256Mi

processor:
  replicaCount: 1
  resources:
    requests:
      cpu: 200m
      memory: 512Mi
  config:
    filtering:
      excludeEnvironments: []  # Keep all environments in dev

telemetryGenerators:
  enabled: true  # Enable test data generators
```

### Production Environment

```yaml
# values-prod.yaml
application:
  environment: "production"

collector:
  replicaCount: 3
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
  
  resources:
    requests:
      cpu: 1000m
      memory: 2Gi
    limits:
      cpu: 2000m
      memory: 4Gi

processor:
  replicaCount: 2
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 8
    targetCPUUtilizationPercentage: 80
  
  resources:
    requests:
      cpu: 2000m
      memory: 4Gi
    limits:
      cpu: 4000m
      memory: 8Gi

grafanaCloud:
  enabled: true
  tempo:
    enabled: true
  prometheus:
    enabled: true

monitoring:
  serviceMonitor:
    enabled: true
    interval: 30s

security:
  podSecurityStandards:
    enforce: "restricted"
  networkPolicy:
    enabled: true
```

### Multi-Environment Setup

```yaml
# values-multi-env.yaml
processor:
  config:
    attributes:
      serviceNameNormalization:
        enabled: true
        pattern: "^(.*)-(dev|staging|prod)$"
    
    filtering:
      excludeEnvironments:
        - dev
        - test
      excludeServices:
        - chaos-monkey
        - load-tester
    
    metricsTransform:
      enabled: true
      standardLabels:
        - cluster
        - environment
        - region
        - team
```

## Monitoring

### ServiceMonitor

```yaml
monitoring:
  serviceMonitor:
    enabled: true
    namespace: "monitoring"
    interval: 30s
    scrapeTimeout: 10s
    labels:
      release: prometheus
```

### Prometheus Rules

```yaml
monitoring:
  prometheusRules:
    enabled: true
    rules:
      - alert: OTelCollectorDown
        expr: up{job="otel-collector"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "OpenTelemetry Collector is down"
      
      - alert: OTelProcessorHighMemory
        expr: process_resident_memory_bytes{job="otel-processor"} > 2000000000
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "OpenTelemetry Processor high memory usage"
```

## Security

### Pod Security Standards

```yaml
security:
  podSecurityStandards:
    enforce: "restricted"
    audit: "restricted"
    warn: "restricted"
```

### Network Policy

```yaml
security:
  networkPolicy:
    enabled: true
    ingress:
      - from:
          - namespaceSelector:
              matchLabels:
                name: application
        ports:
          - protocol: TCP
            port: 4317
          - protocol: TCP
            port: 4318
    egress:
      - to:
          - namespaceSelector:
              matchLabels:
                name: kube-system
        ports:
          - protocol: TCP
            port: 443
```

## Troubleshooting

### Common Issues

1. **Resource Detection Not Working**
   ```bash
   # Check RBAC permissions
   kubectl auth can-i get pods --as=system:serviceaccount:otel-system:otel-dynamic-processors
   
   # Check pod logs
   kubectl logs -n otel-system deployment/otel-dynamic-processors-otel-collector
   ```

2. **Grafana Cloud Authentication Failed**
   ```bash
   # Verify secret exists
   kubectl get secret grafana-cloud-auth -n otel-system
   
   # Check secret contents
   kubectl get secret grafana-cloud-auth -n otel-system -o yaml
   ```

3. **High Memory Usage**
   ```bash
   # Check memory limiter configuration
   kubectl get configmap otel-dynamic-processors-otel-processor-config -n otel-system -o yaml
   
   # Monitor memory usage
   kubectl top pods -n otel-system
   ```

### Debug Mode

```yaml
# Enable debug logging
collector:
  podAnnotations:
    "prometheus.io/scrape": "true"
    "prometheus.io/port": "8888"
  
processor:
  podAnnotations:
    "prometheus.io/scrape": "true"
    "prometheus.io/port": "8889"
```

## Upgrading

### From v0.x to v1.x

```bash
# Backup current values
helm get values otel-processors > backup-values.yaml

# Review breaking changes
helm diff upgrade otel-processors otel-dynamic-processors/otel-dynamic-processors --version 1.0.0

# Perform upgrade
helm upgrade otel-processors otel-dynamic-processors/otel-dynamic-processors --version 1.0.0
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `helm template` and `helm lint`
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **GitHub Issues**: [Report bugs or request features](https://github.com/ChaosKyle/otel-dynamic-processors-lab/issues)
- **Documentation**: [Full documentation](https://github.com/ChaosKyle/otel-dynamic-processors-lab)
- **Community**: [OpenTelemetry Community](https://opentelemetry.io/community/)

## Related Projects

- [OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-collector)
- [OpenTelemetry Collector Contrib](https://github.com/open-telemetry/opentelemetry-collector-contrib)
- [OpenTelemetry Operator](https://github.com/open-telemetry/opentelemetry-operator)
- [Grafana Cloud](https://grafana.com/products/cloud/)