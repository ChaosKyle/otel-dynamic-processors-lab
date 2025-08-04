# Infrastructure Configuration
variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Kubernetes context to use"
  type        = string
  default     = ""
}

variable "namespace" {
  description = "Kubernetes namespace for OpenTelemetry resources"
  type        = string
  default     = "otel-system"
}

variable "deployment_name" {
  description = "Name of the deployment instance"
  type        = string
  default     = "otel-dynamic-processors"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "app_version" {
  description = "Application version"
  type        = string
  default     = "1.0.0"
}

# Grafana Configuration
variable "grafana_url" {
  description = "Grafana instance URL"
  type        = string
}

variable "grafana_api_key" {
  description = "Grafana API key"
  type        = string
  sensitive   = true
}

variable "grafana_cloud_instance_id" {
  description = "Grafana Cloud instance ID"
  type        = string
  sensitive   = true
}

variable "grafana_cloud_api_key" {
  description = "Grafana Cloud API key"
  type        = string
  sensitive   = true
}

variable "grafana_cloud_prometheus_url" {
  description = "Grafana Cloud Prometheus URL"
  type        = string
}

variable "grafana_cloud_tempo_url" {
  description = "Grafana Cloud Tempo URL"
  type        = string
}

variable "grafana_cloud_loki_url" {
  description = "Grafana Cloud Loki URL"
  type        = string
}

# OpenTelemetry Configuration
variable "otel_collector_image" {
  description = "OpenTelemetry Collector image"
  type        = string
  default     = "otel/opentelemetry-collector-contrib:latest"
}

variable "otel_processor_image" {
  description = "OpenTelemetry Processor image"
  type        = string
  default     = "otel/opentelemetry-collector-contrib:latest"
}

variable "enable_grok_processor" {
  description = "Enable Grok AI-powered processor"
  type        = bool
  default     = true
}

variable "grok_api_key" {
  description = "Grok API key for AI-powered recommendations"
  type        = string
  sensitive   = true
  default     = ""
}

# Filter Processor Enforcement Configuration
variable "enable_pii_filtering" {
  description = "Enable PII data filtering and anonymization"
  type        = bool
  default     = true
}

variable "enable_cost_optimization" {
  description = "Enable cost optimization filters"
  type        = bool
  default     = true
}

variable "enable_security_compliance" {
  description = "Enable security compliance filtering"
  type        = bool
  default     = true
}

variable "max_cardinality_threshold" {
  description = "Maximum cardinality threshold for metrics"
  type        = number
  default     = 1000
}

variable "retention_days" {
  description = "Data retention period in days"
  type        = number
  default     = 30
}

variable "allowed_environments" {
  description = "List of allowed environments for production pipelines"
  type        = list(string)
  default     = ["prod", "production"]
}

variable "required_labels" {
  description = "List of required labels for all telemetry data"
  type        = list(string)
  default = [
    "environment",
    "service.name",
    "service.version"
  ]
}

variable "forbidden_patterns" {
  description = "List of forbidden patterns in telemetry data"
  type        = list(string)
  default = [
    "password",
    "secret",
    "api[_-]?key",
    "token",
    "ssn",
    "credit[_-]?card",
    "social[_-]?security"
  ]
}

# Resource Configuration
variable "collector_resources" {
  description = "Resource limits for OpenTelemetry Collector"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

variable "processor_resources" {
  description = "Resource limits for OpenTelemetry Processor"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "200m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
    }
  }
}

variable "enable_autoscaling" {
  description = "Enable horizontal pod autoscaling"
  type        = bool
  default     = true
}

variable "min_replicas" {
  description = "Minimum number of replicas"
  type        = number
  default     = 2
}

variable "max_replicas" {
  description = "Maximum number of replicas"
  type        = number
  default     = 10
}

variable "target_cpu_utilization" {
  description = "Target CPU utilization for autoscaling"
  type        = number
  default     = 70
}

# Monitoring Configuration
variable "enable_metrics" {
  description = "Enable metrics collection"
  type        = bool
  default     = true
}

variable "enable_tracing" {
  description = "Enable distributed tracing"
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Enable structured logging"
  type        = bool
  default     = true
}

variable "log_level" {
  description = "Log level for OpenTelemetry components"
  type        = string
  default     = "info"
  
  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.log_level)
    error_message = "Log level must be one of: debug, info, warn, error."
  }
}

# Dashboard Configuration
variable "create_dashboards" {
  description = "Create Grafana dashboards"
  type        = bool
  default     = true
}

variable "dashboard_folder" {
  description = "Grafana folder for dashboards"
  type        = string
  default     = "OpenTelemetry"
}

variable "alert_contact_points" {
  description = "List of contact points for alerts"
  type        = list(string)
  default     = []
}