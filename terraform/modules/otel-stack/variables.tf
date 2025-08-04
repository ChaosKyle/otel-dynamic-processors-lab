# OpenTelemetry Stack Module Variables

# Basic Configuration
variable "namespace" {
  description = "Kubernetes namespace for the OpenTelemetry stack"
  type        = string
  default     = "otel-system"
}

variable "deployment_name" {
  description = "Name of the deployment instance"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
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

# Container Images
variable "collector_image" {
  description = "OpenTelemetry Collector container image"
  type        = string
  default     = "otel/opentelemetry-collector-contrib:latest"
}

variable "processor_image" {
  description = "OpenTelemetry Processor container image"
  type        = string
  default     = "otel/opentelemetry-collector-contrib:latest"
}

# Credentials
variable "grafana_cloud_credentials" {
  description = "Grafana Cloud credentials"
  type = object({
    instance_id    = string
    api_key       = string
    prometheus_url = string
    tempo_url     = string
    loki_url      = string
  })
  sensitive = true
}

variable "grok_api_key" {
  description = "Grok API key for AI-powered recommendations"
  type        = string
  sensitive   = true
  default     = ""
}

# Filter Processor Configuration
variable "enable_grok_processor" {
  description = "Enable Grok AI-powered processor"
  type        = bool
  default     = true
}

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

# Scaling Configuration
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