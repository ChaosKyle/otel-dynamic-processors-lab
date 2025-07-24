# Alloy Dynamic Processors Helm Chart

This Helm chart deploys Grafana Alloy with advanced dynamic processing capabilities, including intelligent sorting, resource detection, and seamless Grafana Cloud integration.

## 📋 Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- PV provisioner support in the underlying infrastructure (for persistence)
- Grafana Cloud account (optional, for cloud integration)

## 🚀 Quick Start

### 1. Add the Helm Repository (Future)

```bash
# This will be available once published
helm repo add alloy-dynamic-processors https://charts.example.com/alloy-dynamic-processors
helm repo update
```

### 2. Install from Local Chart

```bash
# Clone the repository
git clone https://github.com/ChaosKyle/otel-dynamic-processors-lab
cd otel-dynamic-processors-lab/alloy/helm

# Install with default values
helm install alloy-processors ./alloy-dynamic-processors

# Install with Grafana Cloud integration
helm install alloy-processors ./alloy-dynamic-processors \
  --set grafanaCloud.enabled=true \
  --set grafanaCloud.credentials.instanceId="your-instance-id" \
  --set grafanaCloud.credentials.apiKey="your-api-key"
```

### 3. Install with Values File

```bash
# Development installation
helm install alloy-processors ./alloy-dynamic-processors \
  -f ./alloy-dynamic-processors/examples/values-development.yaml

# Production installation
helm install alloy-processors ./alloy-dynamic-processors \
  -f ./alloy-dynamic-processors/examples/values-production.yaml

# Grafana Cloud optimized installation
helm install alloy-processors ./alloy-dynamic-processors \
  -f ./alloy-dynamic-processors/examples/values-grafana-cloud.yaml
```

## ⚙️ Configuration

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `alloy.image.repository` | Alloy image repository | `grafana/alloy` |
| `alloy.image.tag` | Alloy image tag | `latest` |
| `alloy.config.type` | Configuration type (`basic`, `enhanced-with-sort`, `production`) | `enhanced-with-sort` |
| `alloy.resources.requests.cpu` | CPU resource requests | `500m` |
| `alloy.resources.requests.memory` | Memory resource requests | `1Gi` |
| `alloy.persistence.enabled` | Enable persistence | `true` |
| `alloy.persistence.size` | Persistent volume size | `10Gi` |
| `grafanaCloud.enabled` | Enable Grafana Cloud integration | `true` |
| `grafanaCloud.credentials.instanceId` | Grafana Cloud instance ID | `""` |
| `grafanaCloud.credentials.apiKey` | Grafana Cloud API key | `""` |
| `serviceMonitor.enabled` | Enable Prometheus ServiceMonitor | `true` |
| `rbac.create` | Create RBAC resources | `true` |

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `APP_NAME` | Application name | `alloy-otel-lab` |
| `ENVIRONMENT` | Deployment environment | `production` |
| `LOG_LEVEL` | Logging level | `info` |
| `K8S_CLUSTER_NAME` | Kubernetes cluster name | `k8s-cluster` |
| `CLOUD_REGION` | Cloud region | `us-west-2` |

## 🏗️ Architecture

The chart deploys the following components:

- **Alloy Deployment**: Main Grafana Alloy instance with dynamic processors
- **ConfigMap**: Alloy configuration in River syntax
- **Service**: Exposes OTLP receivers and metrics endpoints
- **ServiceAccount**: For Kubernetes API access
- **RBAC**: Cluster roles for resource discovery
- **PersistentVolumeClaim**: Storage for Alloy data (optional)
- **ServiceMonitor**: Prometheus metrics scraping (optional)
- **Ingress**: External access to Alloy UI (optional)
- **Secret**: Grafana Cloud credentials (optional)

## 📊 Monitoring

The chart includes comprehensive monitoring capabilities:

### Metrics

Alloy exposes metrics on port `8889`:
- `/metrics` - Prometheus metrics
- OpenTelemetry processor metrics
- Grafana Alloy internal metrics

### Health Checks

- **Liveness Probe**: `/-/healthy` on port `12345`
- **Readiness Probe**: `/-/ready` on port `12345`

### ServiceMonitor

When `serviceMonitor.enabled=true`, creates a ServiceMonitor resource for Prometheus Operator:

```yaml
serviceMonitor:
  enabled: true
  interval: 30s
  scrapeTimeout: 10s
  labels:
    prometheus: "kube-prometheus"
```

## 🔧 Configuration Types

### Basic Configuration

Minimal setup with essential processors:

```yaml
alloy:
  config:
    type: "basic"
```

Features:
- Resource detection
- Basic attribute processing
- Environment filtering
- Prometheus metrics export

### Enhanced with Sorting

Full-featured configuration with intelligent sorting:

```yaml
alloy:
  config:
    type: "enhanced-with-sort"
```

Features:
- All basic features
- Intelligent sorting by business priority
- Advanced attribute transformations
- Service mesh integration support
- Grafana Cloud optimizations

### Production Configuration

Production-hardened setup:

```yaml
alloy:
  config:
    type: "production"
```

Features:
- All enhanced features
- Security hardening
- Performance optimizations
- Cost-effective filtering
- Compliance features

## 🌐 Grafana Cloud Integration

### Enable Grafana Cloud

```yaml
grafanaCloud:
  enabled: true
  credentials:
    instanceId: "123456"
    apiKey: "glc_your_api_key_here"
    prometheusUrl: "https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push"
    tempoUrl: "https://tempo-prod-04-eu-west-0.grafana.net:443"
    lokiUrl: "https://logs-prod-006.grafana.net/loki/api/v1/push"
```

### Using Existing Secret

```yaml
grafanaCloud:
  enabled: true
  credentials:
    existingSecret: "my-grafana-cloud-secret"
```

The secret should contain:
- `instance-id`: Grafana Cloud instance ID
- `api-key`: Grafana Cloud API key
- `prometheus-url`: Prometheus push URL
- `tempo-url`: Tempo OTLP URL
- `loki-url`: Loki push URL

## 🏭 Production Deployment

### High Availability

```yaml
alloy:
  replicaCount: 3
  
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                  - alloy-dynamic-processors
          topologyKey: kubernetes.io/hostname

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

podDisruptionBudget:
  enabled: true
  minAvailable: 2
```

### Security

```yaml
alloy:
  securityContext:
    runAsNonRoot: false  # Required for Docker socket access
    runAsUser: 0
    readOnlyRootFilesystem: false
    allowPrivilegeEscalation: false

networkPolicy:
  enabled: true
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: monitoring
      ports:
        - protocol: TCP
          port: 4317
        - protocol: TCP
          port: 4318
```

### Resource Management

```yaml
alloy:
  resources:
    limits:
      cpu: 2000m
      memory: 4Gi
    requests:
      cpu: 1000m
      memory: 2Gi
  
  nodeSelector:
    node-type: "monitoring"
    kubernetes.io/arch: "amd64"
  
  tolerations:
    - key: "monitoring"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
```

## 🧪 Testing

The chart includes built-in tests:

```bash
# Run Helm tests
helm test alloy-processors

# Test output
NAME: alloy-processors
LAST DEPLOYED: ...
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE:     alloy-processors-test-connection
Last Started:   ...
Last Completed: ...
Phase:          Succeeded
```

### Manual Testing

```bash
# Port forward to access Alloy UI
kubectl port-forward svc/alloy-processors 12345:12345

# Access Alloy UI
open http://localhost:12345

# Test OTLP endpoint
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{"resourceSpans": []}'

# Check metrics
curl http://localhost:8889/metrics
```

## 🔄 Upgrading

### Upgrade Chart

```bash
# Upgrade to latest version
helm upgrade alloy-processors ./alloy-dynamic-processors

# Upgrade with new values
helm upgrade alloy-processors ./alloy-dynamic-processors \
  -f new-values.yaml
```

### Migration from OTel Collector

If migrating from the original OTel Collector version:

1. **Backup Configuration**:
   ```bash
   kubectl get configmap otel-collector-config -o yaml > otel-backup.yaml
   ```

2. **Install Alloy in Parallel**:
   ```bash
   helm install alloy-processors ./alloy-dynamic-processors \
     --namespace monitoring-alloy
   ```

3. **Gradually Switch Traffic**:
   ```bash
   # Update application endpoints from OTel Collector to Alloy
   # Monitor both systems during transition
   ```

4. **Remove OTel Collector**:
   ```bash
   helm uninstall otel-collector
   ```

## 🛠️ Troubleshooting

### Common Issues

#### 1. Alloy Pod Not Starting

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=alloy-dynamic-processors

# Check logs
kubectl logs -l app.kubernetes.io/name=alloy-dynamic-processors

# Check events
kubectl describe pod <alloy-pod-name>
```

Common causes:
- Insufficient resources
- Configuration syntax errors
- Missing RBAC permissions

#### 2. Grafana Cloud Connection Issues

```bash
# Test credentials
kubectl exec -it <alloy-pod> -- curl -u "$GRAFANA_CLOUD_INSTANCE_ID:$GRAFANA_CLOUD_API_KEY" \
  "$GRAFANA_CLOUD_PROMETHEUS_URL/api/v1/labels"

# Check secret
kubectl get secret <grafana-cloud-secret> -o yaml
```

#### 3. Resource Detection Not Working

```bash
# Check RBAC permissions
kubectl auth can-i get pods --as=system:serviceaccount:default:alloy-processors

# Check Docker socket access (if using Docker detection)
kubectl exec -it <alloy-pod> -- ls -la /var/run/docker.sock
```

### Debug Mode

Enable debug logging:

```yaml
alloy:
  config:
    env:
      LOG_LEVEL: "debug"
```

## 📚 Examples

### Basic Installation

```bash
helm install alloy-processors ./alloy-dynamic-processors
```

### Development Setup

```bash
helm install alloy-processors ./alloy-dynamic-processors \
  -f examples/values-development.yaml \
  --set ingress.hosts[0].host=alloy.dev.local
```

### Production with Grafana Cloud

```bash
helm install alloy-processors ./alloy-dynamic-processors \
  -f examples/values-production.yaml \
  --set grafanaCloud.credentials.existingSecret=grafana-cloud-prod
```

### Custom Configuration

```bash
helm install alloy-processors ./alloy-dynamic-processors \
  --set alloy.config.type=production \
  --set alloy.replicaCount=5 \
  --set autoscaling.enabled=true \
  --set grafanaCloud.enabled=true
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Test your changes with different values files
4. Submit a pull request

## 📄 License

This chart is licensed under the MIT License. See the main repository for details.

## 🆘 Support

- **Documentation**: See the main [Alloy README](../../README.md)
- **Issues**: Open an issue in the GitHub repository
- **Discussions**: Join the community discussions

---

**🎉 Happy Deploying with Grafana Alloy!**

*This Helm chart provides production-ready deployment of Grafana Alloy with advanced dynamic processing capabilities for modern observability workflows.*