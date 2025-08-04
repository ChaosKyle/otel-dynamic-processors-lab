# OpenTelemetry Stack Module
# This module encapsulates the complete OpenTelemetry dynamic processors stack

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    grafana = {
      source  = "grafana/grafana"
      version = "~> 2.9"
    }
  }
}

# Local variables
locals {
  common_labels = {
    "app.kubernetes.io/name"       = "otel-stack"
    "app.kubernetes.io/instance"   = var.deployment_name
    "app.kubernetes.io/version"    = var.app_version
    "app.kubernetes.io/component"  = "observability"
    "app.kubernetes.io/part-of"    = "opentelemetry"
    "app.kubernetes.io/managed-by" = "terraform"
    "environment"                  = var.environment
  }
}

# Create namespace
resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
    labels = merge(local.common_labels, {
      "name" = var.namespace
    })
    annotations = {
      "terraform.io/managed" = "true"
      "description" = "OpenTelemetry Dynamic Processors Stack"
    }
  }
}

# OpenTelemetry Collector submodule
module "otel_collector" {
  source = "./collector"

  namespace       = kubernetes_namespace.this.metadata[0].name
  deployment_name = var.deployment_name
  environment     = var.environment
  app_version     = var.app_version
  
  image           = var.collector_image
  resources       = var.collector_resources
  replicas        = var.min_replicas
  
  grafana_cloud_credentials = var.grafana_cloud_credentials
  
  enable_metrics  = var.enable_metrics
  enable_tracing  = var.enable_tracing
  enable_logging  = var.enable_logging
  log_level      = var.log_level
  
  common_labels  = local.common_labels
}

# OpenTelemetry Processor submodule
module "otel_processor" {
  source = "./processor"

  namespace       = kubernetes_namespace.this.metadata[0].name
  deployment_name = var.deployment_name
  environment     = var.environment
  app_version     = var.app_version
  
  image           = var.processor_image
  resources       = var.processor_resources
  replicas        = var.min_replicas
  
  grafana_cloud_credentials = var.grafana_cloud_credentials
  grok_api_key             = var.grok_api_key
  
  # Filter processor configuration
  enable_grok_processor        = var.enable_grok_processor
  enable_pii_filtering         = var.enable_pii_filtering
  enable_cost_optimization     = var.enable_cost_optimization
  enable_security_compliance   = var.enable_security_compliance
  max_cardinality_threshold    = var.max_cardinality_threshold
  retention_days              = var.retention_days
  allowed_environments        = var.allowed_environments
  required_labels             = var.required_labels
  forbidden_patterns          = var.forbidden_patterns
  
  common_labels = local.common_labels
  
  depends_on = [module.otel_collector]
}

# Grafana resources submodule
module "grafana_resources" {
  source = "./grafana"
  
  create_dashboards    = var.create_dashboards
  dashboard_folder     = var.dashboard_folder
  alert_contact_points = var.alert_contact_points
  
  grafana_cloud_credentials = var.grafana_cloud_credentials
  namespace                = kubernetes_namespace.this.metadata[0].name
  
  collector_service_name = module.otel_collector.service_name
  processor_service_name = module.otel_processor.service_name
  
  retention_days = var.retention_days
  
  depends_on = [module.otel_collector, module.otel_processor]
}

# Autoscaling submodule
module "autoscaling" {
  source = "./autoscaling"
  
  enable_autoscaling      = var.enable_autoscaling
  namespace              = kubernetes_namespace.this.metadata[0].name
  
  collector_deployment_name = module.otel_collector.deployment_name
  processor_deployment_name = module.otel_processor.deployment_name
  
  min_replicas             = var.min_replicas
  max_replicas             = var.max_replicas
  target_cpu_utilization   = var.target_cpu_utilization
  
  common_labels = local.common_labels
  
  depends_on = [module.otel_collector, module.otel_processor]
}

# RBAC submodule
module "rbac" {
  source = "./rbac"
  
  namespace     = kubernetes_namespace.this.metadata[0].name
  common_labels = local.common_labels
}

# Monitoring submodule
module "monitoring" {
  source = "./monitoring"
  
  namespace        = kubernetes_namespace.this.metadata[0].name
  enable_metrics   = var.enable_metrics
  
  collector_service_name = module.otel_collector.service_name
  processor_service_name = module.otel_processor.service_name
  
  common_labels = local.common_labels
  
  depends_on = [module.otel_collector, module.otel_processor]
}