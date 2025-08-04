# Grafana Configuration - Dashboards, Data Sources, and Alerts

# Create Grafana folder for OpenTelemetry dashboards
resource "grafana_folder" "otel_folder" {
  count = var.create_dashboards ? 1 : 0
  
  title = var.dashboard_folder
}

# Prometheus data source for metrics
resource "grafana_data_source" "prometheus" {
  type = "prometheus"
  name = "OpenTelemetry Prometheus"
  url  = var.grafana_cloud_prometheus_url

  json_data_encoded = jsonencode({
    httpMethod   = "POST"
    queryTimeout = "60s"
    timeInterval = "30s"
  })

  secure_json_data_encoded = jsonencode({
    basicAuthPassword = var.grafana_cloud_api_key
  })

  basic_auth_enabled  = true
  basic_auth_username = var.grafana_cloud_instance_id
}

# Tempo data source for traces
resource "grafana_data_source" "tempo" {
  type = "tempo"
  name = "OpenTelemetry Tempo"
  url  = var.grafana_cloud_tempo_url

  json_data_encoded = jsonencode({
    httpMethod           = "GET"
    tracesToLogsV2 = {
      datasourceUid = grafana_data_source.loki.uid
      tags          = ["service.name", "service.instance.id"]
    }
    tracesToMetrics = {
      datasourceUid = grafana_data_source.prometheus.uid
      tags = [
        {
          key   = "service.name"
          value = "service_name"
        },
        {
          key   = "span.name"
          value = "span_name"
        }
      ]
      queries = [
        {
          name   = "Sample query"
          query  = "sum(rate(traces_spanmetrics_latency_bucket{$$__tags}[5m]))"
        }
      ]
    }
    nodeGraph = {
      enabled = true
    }
    search = {
      hide = false
    }
    lokiSearch = {
      datasourceUid = grafana_data_source.loki.uid
    }
  })

  secure_json_data_encoded = jsonencode({
    basicAuthPassword = var.grafana_cloud_api_key
  })

  basic_auth_enabled  = true
  basic_auth_username = var.grafana_cloud_instance_id
}

# Loki data source for logs
resource "grafana_data_source" "loki" {
  type = "loki"
  name = "OpenTelemetry Loki"
  url  = var.grafana_cloud_loki_url

  json_data_encoded = jsonencode({
    maxLines = 1000
    derivedFields = [
      {
        name          = "TraceID"
        label         = "trace_id"
        url           = "$${__value.raw}"
        datasourceUid = grafana_data_source.tempo.uid
        matcherRegex  = "(?:trace_id|traceID)=([A-Fa-f0-9]+)"
      }
    ]
  })

  secure_json_data_encoded = jsonencode({
    basicAuthPassword = var.grafana_cloud_api_key
  })

  basic_auth_enabled  = true
  basic_auth_username = var.grafana_cloud_instance_id
}

# OpenTelemetry Collector Overview Dashboard
resource "grafana_dashboard" "otel_collector_overview" {
  count = var.create_dashboards ? 1 : 0
  
  folder      = grafana_folder.otel_folder[0].id
  config_json = jsonencode({
    id    = null
    title = "OpenTelemetry Collector Overview"
    tags  = ["opentelemetry", "collector", "observability"]
    timezone = "browser"
    refresh  = "30s"
    time = {
      from = "now-1h"
      to   = "now"
    }
    panels = [
      {
        id    = 1
        title = "Spans Received vs Sent"
        type  = "stat"
        gridPos = {
          h = 8
          w = 12
          x = 0
          y = 0
        }
        targets = [
          {
            expr         = "rate(otelcol_receiver_accepted_spans_total[5m])"
            legendFormat = "Received"
            refId        = "A"
          },
          {
            expr         = "rate(otelcol_exporter_sent_spans_total[5m])"
            legendFormat = "Sent"
            refId        = "B"
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "ops"
            color = {
              mode = "palette-classic"
            }
          }
        }
        options = {
          reduceOptions = {
            values = false
            calcs  = ["lastNotNull"]
            fields = ""
          }
          orientation = "auto"
          textMode    = "auto"
          colorMode   = "value"
          graphMode   = "area"
        }
      },
      {
        id    = 2
        title = "Filter Processor Effectiveness"
        type  = "stat"
        gridPos = {
          h = 8
          w = 12
          x = 12
          y = 0
        }
        targets = [
          {
            expr         = "rate(otelcol_processor_dropped_spans_total{processor=\"filter/security_compliance\"}[5m]) / rate(otelcol_processor_accepted_spans_total{processor=\"filter/security_compliance\"}[5m]) * 100"
            legendFormat = "Security Compliance Drop Rate %"
            refId        = "A"
          },
          {
            expr         = "rate(otelcol_processor_dropped_spans_total{processor=\"filter/cost_optimization\"}[5m]) / rate(otelcol_processor_accepted_spans_total{processor=\"filter/cost_optimization\"}[5m]) * 100"
            legendFormat = "Cost Optimization Drop Rate %"
            refId        = "B"
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "percent"
            color = {
              mode = "thresholds"
            }
            thresholds = {
              steps = [
                {
                  color = "green"
                  value = null
                },
                {
                  color = "yellow"
                  value = 10
                },
                {
                  color = "red"  
                  value = 50
                }
              ]
            }
          }
        }
      },
      {
        id    = 3
        title = "Memory Usage"
        type  = "timeseries"
        gridPos = {
          h = 8
          w = 24
          x = 0
          y = 8
        }
        targets = [
          {
            expr         = "process_resident_memory_bytes{job=\"otel-collector\"} / 1024 / 1024"
            legendFormat = "Collector Memory (MB)"
            refId        = "A"
          },
          {
            expr         = "process_resident_memory_bytes{job=\"otel-processor\"} / 1024 / 1024"
            legendFormat = "Processor Memory (MB)"
            refId        = "B"
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "MB"
            color = {
              mode = "palette-classic"
            }
          }
        }
      },
      {
        id    = 4
        title = "PII Filtering Actions"
        type  = "stat"
        gridPos = {
          h = 8
          w = 12
          x = 0
          y = 16
        }
        targets = [
          {
            expr         = "increase(otelcol_processor_attributes_actions_applied_total{action=\"delete\"}[1h])"
            legendFormat = "PII Fields Removed"
            refId        = "A"
          },
          {
            expr         = "increase(otelcol_processor_attributes_actions_applied_total{action=\"update\"}[1h])"
            legendFormat = "Fields Anonymized"
            refId        = "B"
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "short"
            color = {
              mode = "palette-classic"
            }
          }
        }
      },
      {
        id    = 5
        title = "Grok AI Recommendations"
        type  = "stat"
        gridPos = {
          h = 8
          w = 12
          x = 12
          y = 16
        }
        targets = [
          {
            expr         = "increase(grok_recommendations_total[1h])"
            legendFormat = "Recommendations Generated"
            refId        = "A"
          },
          {
            expr         = "increase(grok_filter_rules_applied_total[1h])"
            legendFormat = "Filter Rules Applied"
            refId        = "B"
          },
          {
            expr         = "increase(grok_policy_violations_total[1h])"
            legendFormat = "Policy Violations Detected"
            refId        = "C"
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "short"
            color = {
              mode = "palette-classic"
            }
          }
        }
      }
    ]
  })
}

# Dynamic Processors Deep Dive Dashboard
resource "grafana_dashboard" "otel_processors_deep_dive" {
  count = var.create_dashboards ? 1 : 0
  
  folder      = grafana_folder.otel_folder[0].id
  config_json = jsonencode({
    id    = null
    title = "OpenTelemetry Dynamic Processors Deep Dive"
    tags  = ["opentelemetry", "processors", "filtering", "compliance"]
    timezone = "browser"
    refresh  = "30s"
    time = {
      from = "now-1h"
      to   = "now"
    }
    panels = [
      {
        id    = 1
        title = "Processor Pipeline Performance"
        type  = "timeseries"
        gridPos = {
          h = 8
          w = 24
          x = 0
          y = 0
        }
        targets = [
          {
            expr         = "rate(otelcol_processor_accepted_spans_total[5m])"
            legendFormat = "{{processor}} - Accepted"
            refId        = "A"
          },
          {
            expr         = "rate(otelcol_processor_dropped_spans_total[5m])"
            legendFormat = "{{processor}} - Dropped"
            refId        = "B"
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "ops"
            color = {
              mode = "palette-classic"
            }
          }
        }
      },
      {
        id    = 2
        title = "Compliance Violations by Type"
        type  = "piechart"
        gridPos = {
          h = 8
          w = 12
          x = 0
          y = 8
        }
        targets = [
          {
            expr         = "increase(otelcol_processor_dropped_spans_total{reason=\"pii_violation\"}[1h])"
            legendFormat = "PII Violations"
            refId        = "A"
          },
          {
            expr         = "increase(otelcol_processor_dropped_spans_total{reason=\"security_violation\"}[1h])"
            legendFormat = "Security Violations"
            refId        = "B"
          },
          {
            expr         = "increase(otelcol_processor_dropped_spans_total{reason=\"cost_optimization\"}[1h])"
            legendFormat = "Cost Optimization"
            refId        = "C"
          },
          {
            expr         = "increase(otelcol_processor_dropped_spans_total{reason=\"label_policy\"}[1h])"
            legendFormat = "Label Policy"
            refId        = "D"
          }
        ]
        options = {
          pieType = "pie"
          tooltip = {
            mode = "single"
          }
          legend = {
            displayMode = "list"
            placement   = "bottom"
          }
        }
      },
      {
        id    = 3
        title = "Data Retention Policy Enforcement"
        type  = "bargauge"
        gridPos = {
          h = 8
          w = 12
          x = 12
          y = 8
        }
        targets = [
          {
            expr         = "sum(rate(otelcol_processor_spans_total{retention_policy=\"standard\"}[5m]))"
            legendFormat = "Standard Retention (${var.retention_days} days)"
            refId        = "A"
          },
          {
            expr         = "sum(rate(otelcol_processor_spans_total{retention_policy=\"extended\"}[5m]))"
            legendFormat = "Extended Retention (${var.retention_days * 2} days)"
            refId        = "B"
          },
          {
            expr         = "sum(rate(otelcol_processor_spans_total{retention_policy=\"short\"}[5m]))"
            legendFormat = "Short Retention (7 days)"
            refId        = "C"
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "ops"
            color = {
              mode = "continuous-GrYlRd"
            }
          }
        }
        options = {
          orientation = "horizontal"
        }
      }
    ]
  })
}

# Alert rules for monitoring
resource "grafana_rule_group" "otel_alerts" {
  count = length(var.alert_contact_points) > 0 ? 1 : 0
  
  name             = "OpenTelemetry Alerts"
  folder_uid       = grafana_folder.otel_folder[0].uid
  interval_seconds = 60

  rule {
    name      = "High Drop Rate - Security Compliance"
    condition = "C"
    
    data {
      ref_id = "A"
      relative_time_range {
        from = 600
        to   = 0
      }
      datasource_uid = grafana_data_source.prometheus.uid
      model = jsonencode({
        expr         = "rate(otelcol_processor_dropped_spans_total{processor=\"filter/security_compliance\"}[5m]) / rate(otelcol_processor_accepted_spans_total{processor=\"filter/security_compliance\"}[5m]) * 100"
        intervalMs   = 1000
        maxDataPoints = 43200
        refId        = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        conditions = [
          {
            evaluator = {
              params = [50]
              type   = "gt"
            }
            operator = {
              type = "and"
            }
            query = {
              queryType = ""
              refId     = "A"
            }
            reducer = {
              params = []
              type   = "last"
            }
            type = "query"
          }
        ]
        datasourceUid = "__expr__"
        expression    = "A"
        hide          = false
        intervalMs    = 1000
        maxDataPoints = 43200
        reducer       = "last"
        refId         = "B"
        type          = "reduce"
      })
    }

    data {
      ref_id = "C"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        conditions = [
          {
            evaluator = {
              params = [0, 0]
              type   = "gt"
            }
            operator = {
              type = "and"
            }
            query = {
              queryType = ""
              refId     = "C"
            }
            reducer = {
              params = []
              type   = "last"
            }
            type = "query"
          }
        ]
        datasourceUid = "__expr__"
        expression    = "B"
        hide          = false
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "C"
        type          = "threshold"
      })
    }

    no_data_state  = "NoData"
    exec_err_state = "Alerting"
    for            = "5m"
    annotations = {
      summary     = "High security compliance drop rate detected"
      description = "Security compliance filter is dropping more than 50% of spans, indicating potential security issues or misconfiguration."
    }
    labels = {
      severity = "warning"
      team     = "platform"
    }
  }

  rule {
    name      = "Grok Processor Down"
    condition = "C"
    
    data {
      ref_id = "A"
      relative_time_range {
        from = 600
        to   = 0
      }
      datasource_uid = grafana_data_source.prometheus.uid
      model = jsonencode({
        expr         = "up{job=\"grok-processor\"}"
        intervalMs   = 1000
        maxDataPoints = 43200
        refId        = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        expression    = "A"
        hide          = false
        intervalMs    = 1000
        maxDataPoints = 43200
        reducer       = "last"
        refId         = "B"
        type          = "reduce"
      })
    }

    data {
      ref_id = "C"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        conditions = [
          {
            evaluator = {
              params = [1]
              type   = "lt"
            }
            operator = {
              type = "and"
            }
            query = {
              queryType = ""
              refId     = "C"
            }
            reducer = {
              params = []
              type   = "last"
            }
            type = "query"
          }
        ]
        datasourceUid = "__expr__"
        expression    = "B"
        hide          = false
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "C"
        type          = "threshold"
      })
    }

    no_data_state  = "NoData"
    exec_err_state = "Alerting"
    for            = "5m"
    annotations = {
      summary     = "Grok AI processor is down"
      description = "The Grok AI-powered recommendation engine is not responding. AI-driven filtering and recommendations are unavailable."
    }
    labels = {
      severity = "critical"
      team     = "platform"
    }
  }
}