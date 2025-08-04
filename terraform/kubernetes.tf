# Kubernetes Resources for OpenTelemetry Dynamic Processors

# ConfigMap for OpenTelemetry Collector configuration
resource "kubernetes_config_map" "otel_collector_config" {
  metadata {
    name      = "otel-collector-config"
    namespace = kubernetes_namespace.otel_namespace.metadata[0].name
    labels    = local.common_labels
  }

  data = {
    "collector-config.yaml" = templatefile("${path.module}/templates/collector-config.yaml.tpl", {
      grafana_cloud_prometheus_url = var.grafana_cloud_prometheus_url
      grafana_cloud_tempo_url     = var.grafana_cloud_tempo_url
      grafana_cloud_loki_url      = var.grafana_cloud_loki_url
      environment                 = var.environment
      log_level                  = var.log_level
      enable_metrics             = var.enable_metrics
      enable_tracing             = var.enable_tracing
      enable_logging             = var.enable_logging
    })
  }
}

# ConfigMap for OpenTelemetry Processor configuration with enhanced filtering
resource "kubernetes_config_map" "otel_processor_config" {
  metadata {
    name      = "otel-processor-config"
    namespace = kubernetes_namespace.otel_namespace.metadata[0].name
    labels    = local.common_labels
  }

  data = {
    "processor-config.yaml" = local.enhanced_filter_config
  }
}

# ConfigMap for Grok policies
resource "kubernetes_config_map" "grok_policies" {
  count = var.enable_grok_processor ? 1 : 0
  
  metadata {
    name      = "grok-policies"
    namespace = kubernetes_namespace.otel_namespace.metadata[0].name
    labels    = local.common_labels
  }

  data = {
    "grok-policies.yaml" = templatefile("${path.module}/templates/grok-policies.yaml.tpl", {
      environment              = var.environment
      required_labels          = var.required_labels
      forbidden_patterns       = var.forbidden_patterns
      enable_pii_filtering     = var.enable_pii_filtering
      enable_security_compliance = var.enable_security_compliance
      enable_cost_optimization = var.enable_cost_optimization
    })
  }
}

# ServiceAccount for OpenTelemetry components
resource "kubernetes_service_account" "otel_service_account" {
  metadata {
    name      = "otel-service-account"
    namespace = kubernetes_namespace.otel_namespace.metadata[0].name
    labels    = local.common_labels
  }
}

# ClusterRole for OpenTelemetry Collector
resource "kubernetes_cluster_role" "otel_collector_role" {
  metadata {
    name   = "otel-collector-role"
    labels = local.common_labels
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "nodes", "services", "endpoints", "namespaces"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["replicasets", "deployments", "daemonsets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = ["replicasets", "deployments", "daemonsets"]
    verbs      = ["get", "list", "watch"]
  }
}

# ClusterRoleBinding for OpenTelemetry Collector
resource "kubernetes_cluster_role_binding" "otel_collector_role_binding" {
  metadata {
    name   = "otel-collector-role-binding"
    labels = local.common_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.otel_collector_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.otel_service_account.metadata[0].name
    namespace = kubernetes_namespace.otel_namespace.metadata[0].name
  }
}

# Deployment for OpenTelemetry Collector
resource "kubernetes_deployment" "otel_collector" {
  metadata {
    name      = "otel-collector"
    namespace = kubernetes_namespace.otel_namespace.metadata[0].name
    labels    = merge(local.common_labels, {
      "app.kubernetes.io/component" = "collector"
    })
  }

  spec {
    replicas = var.min_replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "otel-collector"
        "app.kubernetes.io/instance"  = var.deployment_name
        "app.kubernetes.io/component" = "collector"
      }
    }

    template {
      metadata {
        labels = merge(local.common_labels, {
          "app.kubernetes.io/component" = "collector"
        })
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "8888"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.otel_service_account.metadata[0].name

        container {
          name  = "otel-collector"
          image = var.otel_collector_image

          args = [
            "--config=/etc/otel-collector-config/collector-config.yaml"
          ]

          port {
            name           = "otlp-grpc"
            container_port = 4317
            protocol       = "TCP"
          }

          port {
            name           = "otlp-http"
            container_port = 4318
            protocol       = "TCP"
          }

          port {
            name           = "metrics"
            container_port = 8888
            protocol       = "TCP"
          }

          port {
            name           = "health"
            container_port = 13133
            protocol       = "TCP"
          }

          env {
            name = "GRAFANA_CLOUD_INSTANCE_ID"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.grafana_cloud_credentials.metadata[0].name
                key  = "instance-id"
              }
            }
          }

          env {
            name = "GRAFANA_CLOUD_API_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.grafana_cloud_credentials.metadata[0].name
                key  = "api-key"
              }
            }
          }

          env {
            name = "GRAFANA_CLOUD_PROMETHEUS_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.grafana_cloud_credentials.metadata[0].name
                key  = "prometheus-url"
              }
            }
          }

          env {
            name = "GRAFANA_CLOUD_TEMPO_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.grafana_cloud_credentials.metadata[0].name
                key  = "tempo-url"
              }
            }
          }

          env {
            name = "GRAFANA_CLOUD_LOKI_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.grafana_cloud_credentials.metadata[0].name
                key  = "loki-url"
              }
            }
          }

          resources {
            requests = {
              cpu    = var.collector_resources.requests.cpu
              memory = var.collector_resources.requests.memory
            }
            limits = {
              cpu    = var.collector_resources.limits.cpu
              memory = var.collector_resources.limits.memory
            }
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/otel-collector-config"
            read_only  = true
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 13133
            }
            initial_delay_seconds = 30
            period_seconds        = 30
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 13133
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.otel_collector_config.metadata[0].name
          }
        }
      }
    }
  }
}

# Deployment for OpenTelemetry Processor with Enhanced Filtering
resource "kubernetes_deployment" "otel_processor" {
  metadata {
    name      = "otel-processor"
    namespace = kubernetes_namespace.otel_namespace.metadata[0].name
    labels    = merge(local.common_labels, {
      "app.kubernetes.io/component" = "processor"
    })
  }

  spec {
    replicas = var.min_replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "otel-processor"
        "app.kubernetes.io/instance"  = var.deployment_name
        "app.kubernetes.io/component" = "processor"
      }
    }

    template {
      metadata {
        labels = merge(local.common_labels, {
          "app.kubernetes.io/component" = "processor"
        })
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "8889"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.otel_service_account.metadata[0].name

        container {
          name  = "otel-processor"
          image = var.otel_processor_image

          args = [
            "--config=/etc/otel-processor-config/processor-config.yaml"
          ]

          port {
            name           = "otlp-grpc"
            container_port = 4317
            protocol       = "TCP"
          }

          port {
            name           = "otlp-http"
            container_port = 4318
            protocol       = "TCP"
          }

          port {
            name           = "metrics"
            container_port = 8889
            protocol       = "TCP"
          }

          port {
            name           = "health"
            container_port = 13134
            protocol       = "TCP"
          }

          env {
            name = "GRAFANA_CLOUD_INSTANCE_ID"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.grafana_cloud_credentials.metadata[0].name
                key  = "instance-id"
              }
            }
          }

          env {
            name = "GRAFANA_CLOUD_API_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.grafana_cloud_credentials.metadata[0].name
                key  = "api-key"
              }
            }
          }

          dynamic "env" {
            for_each = var.enable_grok_processor ? [1] : []
            content {
              name = "GROK_API_KEY"
              value_from {
                secret_key_ref {
                  name = kubernetes_secret.grok_api_credentials[0].metadata[0].name
                  key  = "api-key"
                }
              }
            }
          }

          resources {
            requests = {
              cpu    = var.processor_resources.requests.cpu
              memory = var.processor_resources.requests.memory
            }
            limits = {
              cpu    = var.processor_resources.limits.cpu
              memory = var.processor_resources.limits.memory
            }
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/otel-processor-config"
            read_only  = true
          }

          dynamic "volume_mount" {
            for_each = var.enable_grok_processor ? [1] : []
            content {
              name       = "grok-policies"
              mount_path = "/etc/grok-policies"
              read_only  = true
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 13134
            }
            initial_delay_seconds = 30
            period_seconds        = 30
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 13134
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.otel_processor_config.metadata[0].name
          }
        }

        dynamic "volume" {
          for_each = var.enable_grok_processor ? [1] : []
          content {
            name = "grok-policies"
            config_map {
              name = kubernetes_config_map.grok_policies[0].metadata[0].name
            }
          }
        }
      }
    }
  }
}

# Service for OpenTelemetry Collector
resource "kubernetes_service" "otel_collector_service" {
  metadata {
    name      = "otel-collector-service"
    namespace = kubernetes_namespace.otel_namespace.metadata[0].name
    labels    = merge(local.common_labels, {
      "app.kubernetes.io/component" = "collector"
    })
  }

  spec {
    selector = {
      "app.kubernetes.io/name"      = "otel-collector"
      "app.kubernetes.io/instance"  = var.deployment_name
      "app.kubernetes.io/component" = "collector"
    }

    port {
      name        = "otlp-grpc"
      port        = 4317
      target_port = 4317
      protocol    = "TCP"
    }

    port {
      name        = "otlp-http"
      port        = 4318
      target_port = 4318
      protocol    = "TCP"
    }

    port {
      name        = "metrics"
      port        = 8888
      target_port = 8888
      protocol    = "TCP"
    }

    port {
      name        = "health"
      port        = 13133
      target_port = 13133
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# Service for OpenTelemetry Processor
resource "kubernetes_service" "otel_processor_service" {
  metadata {
    name      = "otel-processor-service"
    namespace = kubernetes_namespace.otel_namespace.metadata[0].name
    labels    = merge(local.common_labels, {
      "app.kubernetes.io/component" = "processor"
    })
  }

  spec {
    selector = {
      "app.kubernetes.io/name"      = "otel-processor"
      "app.kubernetes.io/instance"  = var.deployment_name
      "app.kubernetes.io/component" = "processor"
    }

    port {
      name        = "otlp-grpc"
      port        = 4317
      target_port = 4317
      protocol    = "TCP"
    }

    port {
      name        = "otlp-http"
      port        = 4318
      target_port = 4318
      protocol    = "TCP"
    }

    port {
      name        = "metrics"
      port        = 8889
      target_port = 8889
      protocol    = "TCP"
    }

    port {
      name        = "health"
      port        = 13134
      target_port = 13134
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# Horizontal Pod Autoscaler for Collector
resource "kubernetes_horizontal_pod_autoscaler_v2" "otel_collector_hpa" {
  count = var.enable_autoscaling ? 1 : 0

  metadata {
    name      = "otel-collector-hpa"
    namespace = kubernetes_namespace.otel_namespace.metadata[0].name
    labels    = local.common_labels
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.otel_collector.metadata[0].name
    }

    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = var.target_cpu_utilization
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }
  }
}

# Horizontal Pod Autoscaler for Processor
resource "kubernetes_horizontal_pod_autoscaler_v2" "otel_processor_hpa" {
  count = var.enable_autoscaling ? 1 : 0

  metadata {
    name      = "otel-processor-hpa"
    namespace = kubernetes_namespace.otel_namespace.metadata[0].name
    labels    = local.common_labels
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.otel_processor.metadata[0].name
    }

    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = var.target_cpu_utilization
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }
  }
}

# ServiceMonitor for Prometheus scraping (if using Prometheus Operator)
resource "kubernetes_manifest" "otel_collector_service_monitor" {
  count = var.enable_metrics ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "otel-collector-service-monitor"
      namespace = kubernetes_namespace.otel_namespace.metadata[0].name
      labels    = local.common_labels
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name"      = "otel-collector"
          "app.kubernetes.io/component" = "collector"
        }
      }
      endpoints = [
        {
          port = "metrics"
          path = "/metrics"
          interval = "30s"
        }
      ]
    }
  }
}

# ServiceMonitor for Processor
resource "kubernetes_manifest" "otel_processor_service_monitor" {
  count = var.enable_metrics ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "otel-processor-service-monitor"
      namespace = kubernetes_namespace.otel_namespace.metadata[0].name
      labels    = local.common_labels
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name"      = "otel-processor"
          "app.kubernetes.io/component" = "processor"
        }
      }
      endpoints = [
        {
          port = "metrics"
          path = "/metrics"
          interval = "30s"
        }
      ]
    }
  }
}