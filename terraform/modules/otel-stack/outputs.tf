# OpenTelemetry Stack Module Outputs

# Namespace
output "namespace" {
  description = "The Kubernetes namespace where the stack is deployed"
  value       = kubernetes_namespace.this.metadata[0].name
}

# Service Information
output "collector" {
  description = "OpenTelemetry Collector information"
  value = {
    service_name    = module.otel_collector.service_name
    deployment_name = module.otel_collector.deployment_name
    endpoints      = module.otel_collector.endpoints
  }
}

output "processor" {
  description = "OpenTelemetry Processor information"
  value = {
    service_name    = module.otel_processor.service_name
    deployment_name = module.otel_processor.deployment_name
    endpoints      = module.otel_processor.endpoints
  }
}

# Grafana Resources
output "grafana_resources" {
  description = "Grafana resources information"
  value       = module.grafana_resources
}

# Monitoring Endpoints
output "monitoring_endpoints" {
  description = "Monitoring endpoints for the stack"
  value       = module.monitoring.endpoints
}

# RBAC Information
output "rbac" {
  description = "RBAC configuration information"
  value       = module.rbac
}

# Autoscaling Information
output "autoscaling" {
  description = "Autoscaling configuration"
  value       = module.autoscaling
}

# Configuration Summary
output "configuration_summary" {
  description = "Summary of the deployed configuration"
  value = {
    environment = var.environment
    filter_processor_policies = {
      pii_filtering         = var.enable_pii_filtering
      security_compliance   = var.enable_security_compliance
      cost_optimization    = var.enable_cost_optimization
      grok_processor       = var.enable_grok_processor
    }
    monitoring = {
      metrics_enabled = var.enable_metrics
      tracing_enabled = var.enable_tracing
      logging_enabled = var.enable_logging
    }
    scaling = {
      autoscaling_enabled = var.enable_autoscaling
      min_replicas       = var.min_replicas
      max_replicas       = var.max_replicas
    }
  }
}