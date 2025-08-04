# Grok AI-Powered Policy Configuration
# These policies define the enforcement rules for the Grok recommendation engine

policies:
  # Environment Compliance Policy
  - name: "environment_compliance"
    description: "Enforce environment labeling for all telemetry data"
    priority: "high"
    category: "compliance"
    enabled: true
    required_labels:
%{ for label in required_labels ~}
      - "${label}"
%{ endfor ~}
    enforcement: "drop"
    conditions:
      - field: "resource.attributes.environment"
        operator: "exists"
        value: true
      - field: "resource.attributes.deployment.environment"
        operator: "exists"
        value: true
    actions:
      - type: "drop_span"
        reason: "missing_environment_label"
      - type: "alert"
        severity: "warning"
        message: "Span dropped due to missing environment label"

%{ if enable_security_compliance ~}
  # Security Compliance Policy
  - name: "security_compliance"
    description: "Prevent sensitive data in telemetry and enforce security standards"
    priority: "critical"
    category: "security"
    enabled: true
    forbidden_patterns:
%{ for pattern in forbidden_patterns ~}
      - "${pattern}"
%{ endfor ~}
    forbidden_attributes:
      - "password"
      - "secret"
      - "api_key"
      - "token"
      - "ssn"
      - "credit_card"
      - "social_security"
    enforcement: "drop"
    conditions:
      - field: "attributes"
        operator: "contains_pattern"
        patterns: ${jsonencode(forbidden_patterns)}
    actions:
      - type: "drop_span"
        reason: "security_violation"
      - type: "alert"
        severity: "critical"
        message: "Span dropped due to security policy violation"
      - type: "audit_log"
        details: "sensitive_data_detected"

  # Authentication Policy
  - name: "authentication_compliance"
    description: "Enforce authentication requirements for critical services"
    priority: "high"
    category: "security"
    enabled: true
    required_attributes:
      - "user.id"
      - "auth.method"
    critical_services:
      - "payment-service"
      - "user-service"
      - "billing-service"
      - "auth-service"
    enforcement: "flag"
    conditions:
      - field: "resource.attributes.service.name"
        operator: "in"
        values: ["payment-service", "user-service", "billing-service", "auth-service"]
    actions:
      - type: "add_attribute"
        key: "security.audit_required"
        value: "true"
      - type: "alert"
        severity: "warning"
        message: "Critical service span requires enhanced monitoring"
%{ endif ~}

%{ if enable_pii_filtering ~}
  # PII Protection Policy
  - name: "pii_protection"
    description: "Automatically detect and anonymize PII in telemetry data"
    priority: "critical"
    category: "privacy"
    enabled: true
    pii_patterns:
      email: "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b"
      phone: "\\b\\d{3}-\\d{3}-\\d{4}\\b|\\b\\(\\d{3}\\)\\s?\\d{3}-\\d{4}\\b"
      ssn: "\\b\\d{3}-\\d{2}-\\d{4}\\b"
      credit_card: "\\b\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}\\b"
    enforcement: "anonymize"
    anonymization_rules:
      email:
        method: "mask_domain"
        pattern: "^(.{2}).*@(.*)$"
        replacement: "$1***@$2"
      phone:
        method: "mask_middle"
        pattern: "^(\\d{3})\\d{3}(\\d{4})$"
        replacement: "$1***$2"
      ssn:
        method: "mask_all"
        replacement: "***-**-****"
      credit_card:
        method: "mask_middle"
        pattern: "^(\\d{4})\\d{8}(\\d{4})$"
        replacement: "$1********$2"
    actions:
      - type: "anonymize_attribute"
        patterns: ["email", "phone", "ssn", "credit_card"]
      - type: "add_attribute"
        key: "privacy.pii_anonymized"
        value: "true"
      - type: "audit_log"
        details: "pii_anonymization_applied"
%{ endif ~}

%{ if enable_cost_optimization ~}
  # Cost Optimization Policy
  - name: "cost_optimization"
    description: "Reduce telemetry costs by filtering low-value signals"
    priority: "medium"
    category: "cost"
    enabled: true
    drop_rules:
      # Drop debug traces in production
      - condition:
          field: "attributes.log.level"
          operator: "equals"
          value: "DEBUG"
        environment_filter: "${environment == "prod" ? "true" : "false"}"
        reason: "debug_traces_in_production"
      
      # Drop health check spans
      - condition:
          field: "attributes.http.url"
          operator: "matches"
          pattern: ".*/health.*|.*/ping.*|.*/ready.*"
        reason: "health_check_noise"
      
      # Drop high-cardinality metrics
      - condition:
          field: "metric.labels"
          operator: "cardinality_exceeds"
          threshold: 1000
        reason: "high_cardinality_metric"
      
      # Drop short-duration internal spans
      - condition:
          field: "span.kind"
          operator: "equals"
          value: "internal"
        duration_threshold: "1ms"
        reason: "short_internal_span"
    
    sampling_rules:
      # Sample low-priority spans at reduced rate
      - condition:
          field: "attributes.business.priority"
          operator: "equals"
          value: "low"
        sampling_rate: 0.01  # 1%
        reason: "low_priority_sampling"
      
      # Full sampling for errors and critical services
      - condition:
          field: "span.status.code"
          operator: "equals"
          value: "ERROR"
        sampling_rate: 1.0  # 100%
        reason: "error_traces_full_sampling"
    
    cost_thresholds:
      daily_ingestion_mb: 1000
      monthly_retention_gb: 50
      alert_threshold_percentage: 80
    
    actions:
      - type: "drop_span"
        conditions: ["debug_traces", "health_checks", "short_spans"]
      - type: "sample_span"
        rate_based_on: "business_priority"
      - type: "alert"
        severity: "info"
        message: "Cost optimization rule applied"
      - type: "metrics"
        increment: "cost_optimization.rules_applied"
%{ endif ~}

  # Data Retention Policy
  - name: "data_retention"
    description: "Enforce data retention policies based on business requirements"
    priority: "medium"
    category: "governance"
    enabled: true
    retention_rules:
      # Critical business data - extended retention
      - condition:
          field: "attributes.business.priority"
          operator: "equals"
          value: "critical"
        retention_days: 365
        storage_tier: "hot"
        reason: "critical_business_data"
      
      # Standard business data
      - condition:
          field: "attributes.business.priority"
          operator: "equals"
          value: "standard"
        retention_days: 90
        storage_tier: "warm"
        reason: "standard_business_data"
      
      # Debug and test data - short retention
      - condition:
          field: "attributes.log.level"
          operator: "equals"
          value: "DEBUG"
        retention_days: 7
        storage_tier: "cold"
        reason: "debug_data_short_retention"
      
      # Error traces - extended retention for analysis
      - condition:
          field: "span.status.code"
          operator: "equals"
          value: "ERROR"
        retention_days: 180
        storage_tier: "hot"
        reason: "error_analysis_retention"
    
    actions:
      - type: "add_attribute"
        key: "retention.policy"
        value_from: "retention_rule.reason"
      - type: "add_attribute"
        key: "retention.expires_at"
        value_from: "calculated_expiry_date"
      - type: "add_attribute"
        key: "retention.storage_tier"
        value_from: "retention_rule.storage_tier"

  # Quality Assurance Policy
  - name: "data_quality"
    description: "Ensure telemetry data quality and completeness"
    priority: "high"
    category: "quality"
    enabled: true
    quality_checks:
      # Required span attributes
      - name: "span_completeness"
        required_fields:
          - "span.name"
          - "span.start_time"
          - "span.end_time"
          - "resource.attributes.service.name"
        action: "flag_incomplete"
      
      # Trace continuity
      - name: "trace_continuity"
        checks:
          - "parent_span_exists"
          - "trace_id_valid"
          - "span_id_unique"
        action: "flag_orphaned"
      
      # Timestamp validation
      - name: "timestamp_validation"
        checks:
          - "start_before_end"
          - "reasonable_duration"
          - "not_future_dated"
        action: "flag_invalid_time"
      
      # Attribute validation
      - name: "attribute_validation"
        checks:
          - "no_null_values"
          - "reasonable_string_length"
          - "valid_enum_values"
        action: "flag_invalid_attributes"
    
    actions:
      - type: "add_attribute"
        key: "data_quality.validated"
        value: "true"
      - type: "add_attribute"
        key: "data_quality.score"
        value_from: "calculated_quality_score"
      - type: "metrics"
        increment: "data_quality.validations_performed"

# Global Settings
global_settings:
  # Grok API Configuration
  grok_api:
    max_sample_size: 100
    sampling_interval: "5m"
    enable_caching: true
    cache_expiration: "1h"
    enable_rate_limiting: true
    rate_limit_rpm: 60
  
  # Processing Configuration
  processing:
    batch_size: 1000
    processing_timeout: "30s"
    max_concurrent_policies: 10
    enable_parallel_processing: true
  
  # Monitoring Configuration
  monitoring:
    enable_metrics: true
    metrics_port: 8890
    enable_health_checks: true
    health_check_port: 13135
    enable_debug_logging: false
  
  # Alerting Configuration
  alerting:
    enable_alerts: true
    alert_thresholds:
      policy_violations_per_minute: 100
      processing_errors_per_minute: 10
      memory_usage_percentage: 80
      cpu_usage_percentage: 70
    notification_channels:
      - "slack"
      - "email"
      - "webhook"