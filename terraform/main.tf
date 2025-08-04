terraform {
  required_version = ">= 1.0"
  
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
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Configure the Kubernetes Provider
provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}

# Configure the Helm Provider
provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kube_context
  }
}

# Configure the Grafana Provider
provider "grafana" {
  url  = var.grafana_url
  auth = var.grafana_api_key
}

# Local variables
locals {
  namespace = var.namespace
  common_labels = {
    "app.kubernetes.io/name"       = "otel-dynamic-processors"
    "app.kubernetes.io/instance"   = var.deployment_name
    "app.kubernetes.io/version"    = var.app_version
    "app.kubernetes.io/component"  = "observability"
    "app.kubernetes.io/part-of"    = "opentelemetry"
    "app.kubernetes.io/managed-by" = "terraform"
    "environment"                  = var.environment
  }
  
  # Enhanced filter processor configuration with comprehensive enforcement
  enhanced_filter_config = templatefile("${path.module}/templates/enhanced-filter-processor.yaml.tpl", {
    environment              = var.environment
    enable_pii_filtering     = var.enable_pii_filtering
    enable_cost_optimization = var.enable_cost_optimization
    enable_security_compliance = var.enable_security_compliance
    max_cardinality_threshold = var.max_cardinality_threshold
    retention_days           = var.retention_days
    allowed_environments     = var.allowed_environments
    required_labels          = var.required_labels
    forbidden_patterns       = var.forbidden_patterns
  })
}

# Create namespace
resource "kubernetes_namespace" "otel_namespace" {
  metadata {
    name = local.namespace
    labels = merge(local.common_labels, {
      "name" = local.namespace
    })
    annotations = {
      "terraform.io/managed" = "true"
      "description" = "OpenTelemetry Dynamic Processors with Enhanced Filtering"
    }
  }
}

# Secret for Grafana Cloud credentials
resource "kubernetes_secret" "grafana_cloud_credentials" {
  metadata {
    name      = "grafana-cloud-credentials"
    namespace = kubernetes_namespace.otel_namespace.metadata[0].name
    labels    = local.common_labels
  }

  data = {
    instance-id    = var.grafana_cloud_instance_id
    api-key       = var.grafana_cloud_api_key
    prometheus-url = var.grafana_cloud_prometheus_url
    tempo-url     = var.grafana_cloud_tempo_url
    loki-url      = var.grafana_cloud_loki_url
  }

  type = "Opaque"
}

# Secret for Grok API credentials
resource "kubernetes_secret" "grok_api_credentials" {
  count = var.enable_grok_processor ? 1 : 0
  
  metadata {
    name      = "grok-api-credentials"
    namespace = kubernetes_namespace.otel_namespace.metadata[0].name
    labels    = local.common_labels
  }

  data = {
    api-key = var.grok_api_key
  }

  type = "Opaque"
}