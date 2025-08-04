# Terraform Outputs

# Namespace Information
output "namespace" {
  description = "The Kubernetes namespace where OpenTelemetry resources are deployed"
  value       = kubernetes_namespace.otel_namespace.metadata[0].name
}

output "namespace_labels" {
  description = "Labels applied to the OpenTelemetry namespace"
  value       = kubernetes_namespace.otel_namespace.metadata[0].labels
}

# Service Endpoints
output "collector_service_name" {
  description = "Name of the OpenTelemetry Collector service"
  value       = kubernetes_service.otel_collector_service.metadata[0].name
}

output "collector_service_endpoints" {
  description = "OpenTelemetry Collector service endpoints"
  value = {
    otlp_grpc = "http://${kubernetes_service.otel_collector_service.metadata[0].name}.${kubernetes_namespace.otel_namespace.metadata[0].name}.svc.cluster.local:4317"
    otlp_http = "http://${kubernetes_service.otel_collector_service.metadata[0].name}.${kubernetes_namespace.otel_namespace.metadata[0].name}.svc.cluster.local:4318"
    metrics   = "http://${kubernetes_service.otel_collector_service.metadata[0].name}.${kubernetes_namespace.otel_namespace.metadata[0].name}.svc.cluster.local:8888"
    health    = "http://${kubernetes_service.otel_collector_service.metadata[0].name}.${kubernetes_namespace.otel_namespace.metadata[0].name}.svc.cluster.local:13133"
  }
}

output "processor_service_name" {
  description = "Name of the OpenTelemetry Processor service"
  value       = kubernetes_service.otel_processor_service.metadata[0].name
}

output "processor_service_endpoints" {
  description = "OpenTelemetry Processor service endpoints"
  value = {
    otlp_grpc = "http://${kubernetes_service.otel_processor_service.metadata[0].name}.${kubernetes_namespace.otel_namespace.metadata[0].name}.svc.cluster.local:4317"
    otlp_http = "http://${kubernetes_service.otel_processor_service.metadata[0].name}.${kubernetes_namespace.otel_namespace.metadata[0].name}.svc.cluster.local:4318"
    metrics   = "http://${kubernetes_service.otel_processor_service.metadata[0].name}.${kubernetes_namespace.otel_namespace.metadata[0].name}.svc.cluster.local:8889"
    health    = "http://${kubernetes_service.otel_processor_service.metadata[0].name}.${kubernetes_namespace.otel_namespace.metadata[0].name}.svc.cluster.local:13134"
  }
}

# Deployment Information
output "collector_deployment_info" {
  description = "OpenTelemetry Collector deployment information"
  value = {
    name      = kubernetes_deployment.otel_collector.metadata[0].name
    namespace = kubernetes_deployment.otel_collector.metadata[0].namespace
    replicas  = kubernetes_deployment.otel_collector.spec[0].replicas
    image     = var.otel_collector_image
    labels    = kubernetes_deployment.otel_collector.metadata[0].labels
  }
}

output "processor_deployment_info" {
  description = "OpenTelemetry Processor deployment information"
  value = {
    name      = kubernetes_deployment.otel_processor.metadata[0].name
    namespace = kubernetes_deployment.otel_processor.metadata[0].namespace
    replicas  = kubernetes_deployment.otel_processor.spec[0].replicas
    image     = var.otel_processor_image
    labels    = kubernetes_deployment.otel_processor.metadata[0].labels
  }
}

# Configuration Information
output "filter_processor_policies" {
  description = "Summary of filter processor enforcement policies"
  value = {
    pii_filtering           = var.enable_pii_filtering
    security_compliance     = var.enable_security_compliance
    cost_optimization      = var.enable_cost_optimization
    grok_processor         = var.enable_grok_processor
    max_cardinality        = var.max_cardinality_threshold
    retention_days         = var.retention_days
    allowed_environments   = var.allowed_environments
    required_labels        = var.required_labels
    forbidden_patterns     = var.forbidden_patterns
  }
}

# Grafana Information
output "grafana_dashboards" {
  description = "Information about created Grafana dashboards"
  value = var.create_dashboards ? {
    folder_id             = grafana_folder.otel_folder[0].id
    folder_title          = grafana_folder.otel_folder[0].title
    collector_dashboard   = "OpenTelemetry Collector Overview"
    processors_dashboard  = "OpenTelemetry Dynamic Processors Deep Dive"
  } : null
}

output "grafana_data_sources" {
  description = "Grafana data source information"
  value = {
    prometheus = {
      name = grafana_data_source.prometheus.name
      uid  = grafana_data_source.prometheus.uid
      url  = grafana_data_source.prometheus.url
    }
    tempo = {
      name = grafana_data_source.tempo.name
      uid  = grafana_data_source.tempo.uid
      url  = grafana_data_source.tempo.url
    }
    loki = {
      name = grafana_data_source.loki.name
      uid  = grafana_data_source.loki.uid
      url  = grafana_data_source.loki.url
    }
  }
}

# Monitoring Information
output "monitoring_endpoints" {
  description = "Monitoring and health check endpoints"
  value = {
    collector_metrics = "http://${kubernetes_service.otel_collector_service.metadata[0].name}.${kubernetes_namespace.otel_namespace.metadata[0].name}.svc.cluster.local:8888/metrics"
    collector_health  = "http://${kubernetes_service.otel_collector_service.metadata[0].name}.${kubernetes_namespace.otel_namespace.metadata[0].name}.svc.cluster.local:13133"
    processor_metrics = "http://${kubernetes_service.otel_processor_service.metadata[0].name}.${kubernetes_namespace.otel_namespace.metadata[0].name}.svc.cluster.local:8889/metrics"
    processor_health  = "http://${kubernetes_service.otel_processor_service.metadata[0].name}.${kubernetes_namespace.otel_namespace.metadata[0].name}.svc.cluster.local:13134"
  }
}

# Security Information
output "security_configuration" {
  description = "Security configuration summary"
  sensitive   = true
  value = {
    service_account        = kubernetes_service_account.otel_service_account.metadata[0].name
    cluster_role          = kubernetes_cluster_role.otel_collector_role.metadata[0].name
    secrets_created       = [
      kubernetes_secret.grafana_cloud_credentials.metadata[0].name,
      var.enable_grok_processor ? kubernetes_secret.grok_api_credentials[0].metadata[0].name : null
    ]
    rbac_configured       = true
    tls_configuration     = "internal-only"
  }
}

# Resource Allocation
output "resource_allocation" {
  description = "Resource allocation for OpenTelemetry components"
  value = {
    collector = {
      requests = var.collector_resources.requests
      limits   = var.collector_resources.limits
    }
    processor = {
      requests = var.processor_resources.requests
      limits   = var.processor_resources.limits
    }
    autoscaling = {
      enabled           = var.enable_autoscaling
      min_replicas      = var.min_replicas
      max_replicas      = var.max_replicas
      target_cpu        = var.target_cpu_utilization
    }
  }
}

# Compliance Report
output "compliance_report" {
  description = "Compliance and enforcement configuration summary"
  value = {
    environment           = var.environment
    data_retention = {
      standard_days       = var.retention_days
      critical_days       = var.retention_days * 2
      debug_days         = 7
    }
    policy_enforcement = {
      pii_protection      = var.enable_pii_filtering
      security_compliance = var.enable_security_compliance
      cost_optimization   = var.enable_cost_optimization
      label_policies      = length(var.required_labels) > 0
    }
    ai_powered_features = {
      grok_processor      = var.enable_grok_processor
      recommendations     = var.enable_grok_processor
      auto_filtering      = var.enable_grok_processor
    }
    monitoring = {
      metrics_enabled     = var.enable_metrics
      tracing_enabled     = var.enable_tracing
      logging_enabled     = var.enable_logging
      dashboards_created  = var.create_dashboards
      alerts_configured   = length(var.alert_contact_points) > 0
    }
  }
}

# Quick Start Commands
output "quick_start_commands" {
  description = "Commands to get started with the deployed OpenTelemetry stack"
  value = {
    check_status = "kubectl get pods -n ${kubernetes_namespace.otel_namespace.metadata[0].name}"
    view_logs = {
      collector = "kubectl logs -n ${kubernetes_namespace.otel_namespace.metadata[0].name} deployment/${kubernetes_deployment.otel_collector.metadata[0].name}"
      processor = "kubectl logs -n ${kubernetes_namespace.otel_namespace.metadata[0].name} deployment/${kubernetes_deployment.otel_processor.metadata[0].name}"
    }
    port_forward = {
      collector_metrics = "kubectl port-forward -n ${kubernetes_namespace.otel_namespace.metadata[0].name} service/${kubernetes_service.otel_collector_service.metadata[0].name} 8888:8888"
      processor_metrics = "kubectl port-forward -n ${kubernetes_namespace.otel_namespace.metadata[0].name} service/${kubernetes_service.otel_processor_service.metadata[0].name} 8889:8889"
      collector_otlp    = "kubectl port-forward -n ${kubernetes_namespace.otel_namespace.metadata[0].name} service/${kubernetes_service.otel_collector_service.metadata[0].name} 4317:4317 4318:4318"
    }
    test_endpoint = "curl http://localhost:13133 # (after port-forward)"
  }
}

# Configuration Files
output "configuration_files" {
  description = "Generated configuration files for reference"
  value = {
    collector_config = "See ConfigMap: ${kubernetes_config_map.otel_collector_config.metadata[0].name}"
    processor_config = "See ConfigMap: ${kubernetes_config_map.otel_processor_config.metadata[0].name}"
    grok_policies   = var.enable_grok_processor ? "See ConfigMap: ${kubernetes_config_map.grok_policies[0].metadata[0].name}" : "Not enabled"
  }
}

# External Dependencies
output "external_dependencies" {
  description = "External services and dependencies"
  value = {
    grafana_cloud = {
      prometheus_url = var.grafana_cloud_prometheus_url
      tempo_url     = var.grafana_cloud_tempo_url
      loki_url      = var.grafana_cloud_loki_url
    }
    grafana_instance = {
      url = var.grafana_url
    }
    grok_api = {
      enabled = var.enable_grok_processor
    }
  }
}