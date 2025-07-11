# Kubernetes Deployment Guide

This guide explains how to deploy the OpenTelemetry Dynamic Processors Lab to Kubernetes using Helm.

## 📚 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration Examples](#configuration-examples)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Upgrade](#upgrade)
- [Uninstall](#uninstall)
- [Custom Values](#custom-values)
- [Monitoring](#monitoring)
- [Security](#security)
- [Support](#support)

## Prerequisites

- Kubernetes cluster (1.19+)
- Helm 3.0+
- kubectl configured to access your cluster

## Quick Start

### 1. Install with Default Values

```bash
# Install in default namespace
helm install otel-processors ./helm/otel-dynamic-processors

# Install in specific namespace
kubectl create namespace otel-system
helm install otel-processors ./helm/otel-dynamic-processors --namespace otel-system
```

### 2. Install with Grafana Cloud

```bash
# Create Grafana Cloud secret
kubectl create secret generic grafana-cloud-auth \
  --from-literal=instanceId="your-instance-id" \
  --from-literal=apiKey="your-api-key"

# Install with Grafana Cloud integration
helm install otel-processors ./helm/otel-dynamic-processors \
  --set grafanaCloud.enabled=true \
  --set grafanaCloud.tempo.enabled=true \
  --set grafanaCloud.tempo.endpoint="https://tempo-prod-04-eu-west-0.grafana.net:443" \
  --set grafanaCloud.prometheus.enabled=true \
  --set grafanaCloud.prometheus.endpoint="https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push"
```

### 3. Production Installation

```bash
# Install with production values
helm install otel-processors ./helm/otel-dynamic-processors \
  --namespace otel-system \
  --values ./helm/otel-dynamic-processors/examples/values-production.yaml
```

## Configuration Examples

### Development Environment

```bash
helm install otel-processors ./helm/otel-dynamic-processors \
  --namespace otel-dev \
  --values ./helm/otel-dynamic-processors/examples/values-development.yaml
```

### Grafana Cloud Optimized

```bash
# Create secret first
kubectl create secret generic grafana-cloud-auth \
  --namespace otel-system \
  --from-literal=instanceId="123456" \
  --from-literal=apiKey="your-api-key"

# Install with Grafana Cloud optimization
helm install otel-processors ./helm/otel-dynamic-processors \
  --namespace otel-system \
  --values ./helm/otel-dynamic-processors/examples/values-grafana-cloud.yaml
```

## Verification

### Check Deployment Status

```bash
# Check pods
kubectl get pods -n otel-system

# Check services
kubectl get svc -n otel-system

# Check logs
kubectl logs -n otel-system deployment/otel-processors-otel-collector
kubectl logs -n otel-system deployment/otel-processors-otel-processor
```

### Test Data Flow

```bash
# Port forward collector
kubectl port-forward -n otel-system svc/otel-processors-otel-collector 4317:4317

# Send test trace (in another terminal)
curl -X POST http://localhost:4317/v1/traces \
  -H "Content-Type: application/json" \
  -d '{"resourceSpans":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"test-service"}}]},"scopeSpans":[{"spans":[{"traceId":"0123456789abcdef0123456789abcdef","spanId":"0123456789abcdef","name":"test-span","startTimeUnixNano":"1640995200000000000","endTimeUnixNano":"1640995201000000000"}]}]}]}'
```

### Check Metrics

```bash
# Port forward metrics
kubectl port-forward -n otel-system svc/otel-processors-otel-collector 8888:8888

# View metrics (in another terminal)
curl http://localhost:8888/metrics
```

## Troubleshooting

### Common Issues

1. **Resource Detection Not Working**
   ```bash
   # Check RBAC
   kubectl auth can-i get pods --as=system:serviceaccount:otel-system:otel-processors

   # Check pod logs
   kubectl logs -n otel-system deployment/otel-processors-otel-collector
   ```

2. **Configuration Errors**
   ```bash
   # Check configmap
   kubectl get configmap -n otel-system otel-processors-otel-collector-config -o yaml

   # Validate configuration
   kubectl describe pod -n otel-system -l app.kubernetes.io/component=collector
   ```

3. **Service Discovery Issues**
   ```bash
   # Check service endpoints
   kubectl get endpoints -n otel-system

   # Check network policies
   kubectl get networkpolicy -n otel-system
   ```

### Debug Commands

```bash
# Get all resources
kubectl get all -n otel-system

# Describe problematic pod
kubectl describe pod -n otel-system <pod-name>

# Check events
kubectl get events -n otel-system --sort-by=.metadata.creationTimestamp

# Debug collector config
kubectl exec -n otel-system deployment/otel-processors-otel-collector -- cat /etc/otelcol-contrib/config.yaml
```

## Upgrade

```bash
# Upgrade with new values
helm upgrade otel-processors ./helm/otel-dynamic-processors \
  --namespace otel-system \
  --values ./helm/otel-dynamic-processors/examples/values-production.yaml

# Check upgrade status
helm status otel-processors -n otel-system
```

## Uninstall

```bash
# Uninstall Helm release
helm uninstall otel-processors -n otel-system

# Clean up namespace (optional)
kubectl delete namespace otel-system
```

## Custom Values

Create your own values file:

```yaml
# custom-values.yaml
application:
  name: "my-app"
  environment: "production"
  cluster: "my-cluster"

collector:
  replicaCount: 3
  resources:
    requests:
      cpu: 500m
      memory: 1Gi

processor:
  replicaCount: 2
  resources:
    requests:
      cpu: 1000m
      memory: 2Gi

grafanaCloud:
  enabled: true
  tempo:
    enabled: true
    endpoint: "your-tempo-endpoint"
  prometheus:
    enabled: true
    endpoint: "your-prometheus-endpoint"
```

Then install:

```bash
helm install otel-processors ./helm/otel-dynamic-processors \
  --namespace otel-system \
  --values custom-values.yaml
```

## Monitoring

### Prometheus Integration

```yaml
monitoring:
  serviceMonitor:
    enabled: true
    namespace: "monitoring"
    labels:
      release: prometheus
```

### Grafana Dashboards

The chart includes pre-configured dashboards that can be imported into Grafana:

1. OpenTelemetry Pipeline Overview
2. Collector Performance Metrics
3. Processor Performance Metrics
4. Resource Detection Status

## Security

### Pod Security Standards

```yaml
security:
  podSecurityStandards:
    enforce: "restricted"
```

### Network Policies

```yaml
security:
  networkPolicy:
    enabled: true
    ingress:
      - from:
          - namespaceSelector:
              matchLabels:
                name: applications
```

## Support

For issues and questions:
- Check the [troubleshooting guide](README.md#troubleshooting)
- Review [examples](examples/)
- Open an issue on GitHub