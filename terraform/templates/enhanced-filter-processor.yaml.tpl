# Enhanced Filter Processor Configuration with Comprehensive Enforcement
# This configuration enforces security compliance, cost optimization, PII filtering, and data retention policies

processors:
  # Memory limiter to prevent OOM
  memory_limiter:
    check_interval: 1s
    limit_percentage: 75
    spike_limit_percentage: 25

  # Resource detection processor
  resourcedetection:
    detectors: [docker, k8s_node, k8s_pod, system, process, env]
    docker:
      resource_attributes:
        host.name:
          enabled: true
        container.image.name:
          enabled: true
        container.image.tag:
          enabled: true
    k8s_node:
      auth_type: serviceAccount
      resource_attributes:
        k8s.node.name:
          enabled: true
        k8s.node.uid:
          enabled: true
    k8s_pod:
      auth_type: serviceAccount
      resource_attributes:
        k8s.pod.name:
          enabled: true
        k8s.pod.uid:
          enabled: true
        k8s.namespace.name:
          enabled: true
        k8s.deployment.name:
          enabled: true
    system:
      resource_attributes:
        host.name:
          enabled: true
        host.arch:
          enabled: true
        os.type:
          enabled: true
    process:
      resource_attributes:
        process.pid:
          enabled: true
        process.executable.name:
          enabled: true

  # Enhanced attribute processor for compliance and enrichment
  attributes/compliance:
    actions:
      # Add compliance metadata
      - key: compliance.processed_at
        value: "$${timestamp}"
        action: insert
      - key: compliance.environment
        value: "${environment}"
        action: insert
      - key: compliance.terraform_managed
        value: "true"
        action: insert
      
      # Normalize service names
      - key: service.name
        pattern: ^(.*)-(dev|staging|prod)$$
        action: extract
        to_attributes:
          - key: service.base_name
            pattern: $$1
          - key: service.detected_environment
            pattern: $$2
      
      # Add Grafana-specific labels
      - key: grafana.service.name
        from_attribute: service.name
        action: insert
      - key: grafana.environment
        from_attribute: deployment.environment
        action: insert
      - key: grafana.cluster
        from_attribute: k8s.cluster.name
        action: insert
      
      # Business priority scoring
      - key: business.priority
        value: "critical"
        action: insert
        conditions:
          - key: service.name
            pattern: ".*(payment|billing|auth).*"
      - key: business.priority
        value: "high"
        action: insert
        conditions:
          - key: service.name
            pattern: ".*(user|order|notification).*"
      - key: business.priority
        value: "medium"
        action: insert
        conditions:
          - key: business.priority
            exists: false

%{ if enable_pii_filtering ~}
  # PII and sensitive data filtering
  attributes/pii_filter:
    actions:
      # Remove sensitive headers
      - key: http.request.header.authorization
        action: delete
      - key: http.request.header.x-api-key
        action: delete
      - key: http.request.header.cookie
        action: delete
      
      # Anonymize email addresses
      - key: user.email
        pattern: "^(.{2}).*@(.*)$$"
        action: update
        value: "$$1***@$$2"
      
      # Mask credit card numbers
      - key: payment.card_number
        pattern: "^(.{4}).*(.{4})$$"
        action: update
        value: "$$1****$$2"
      
      # Remove SSN patterns
      - key: user.ssn
        action: delete
      
      # Remove any attribute containing forbidden patterns
%{ for pattern in forbidden_patterns ~}
      - key: "*"
        pattern: ".*${pattern}.*"
        action: delete
%{ endfor ~}
%{ endif ~}

%{ if enable_security_compliance ~}
  # Security compliance processor
  filter/security_compliance:
    error_mode: ignore
    traces:
      span:
        # Drop spans with security violations
        - 'attributes["security.violation"] == "true"'
        - 'attributes["auth.failed"] == "true"'
        - 'resource.attributes["security.scan_required"] == "true" and resource.attributes["security.scan_passed"] != "true"'
        
        # Drop spans from unauthorized environments in production
%{ if environment == "prod" ~}
        - 'resource.attributes["environment"] == "dev"'
        - 'resource.attributes["environment"] == "test"'
        - 'resource.attributes["deployment.environment"] == "development"'
%{ endif ~}
        
        # Drop health check and internal monitoring spans
        - 'attributes["http.url"] =~ ".*/health.*"'
        - 'attributes["http.url"] =~ ".*/ping.*"'
        - 'attributes["http.url"] =~ ".*/metrics.*"'
        - 'span.name =~ ".*health.*"'
        - 'span.name =~ ".*heartbeat.*"'
        
        # Drop debug and test spans in production
%{ if environment == "prod" ~}
        - 'attributes["debug.enabled"] == "true"'
        - 'attributes["log.level"] == "DEBUG"'
        - 'resource.attributes["service.name"] =~ ".*-test"'
        - 'resource.attributes["service.name"] =~ ".*debug.*"'
%{ endif ~}
        
    metrics:
      metric:
        # Drop debug metrics in production
%{ if environment == "prod" ~}
        - 'resource.attributes["environment"] == "dev"'
        - 'name =~ ".*debug.*"'
        - 'name =~ ".*test.*"'
%{ endif ~}
%{ endif ~}

%{ if enable_cost_optimization ~}
  # Cost optimization filter
  filter/cost_optimization:
    error_mode: ignore
    traces:
      span:
        # Drop high-cardinality spans
        - 'attributes["cardinality.estimate"] > ${max_cardinality_threshold}'
        
        # Drop noisy spans
        - 'attributes["span.kind"] == "internal" and duration < 1000000'  # < 1ms internal spans
        - 'attributes["noise.level"] == "high"'
        
        # Drop low-value spans based on sampling
        - 'attributes["sampling.priority"] == "low" and random() > 0.01'  # Keep only 1% of low priority
        
        # Drop spans older than retention period
        - 'unix_timestamp() - span.start_time_unix_nano / 1000000000 > ${retention_days} * 86400'
        
    metrics:
      metric:
        # Drop high-cardinality metrics
        - 'labels["cardinality"] > ${max_cardinality_threshold}'
        
        # Drop metrics with too many labels
        - 'len(labels) > 10'
        
        # Drop custom metrics that are rarely used
        - 'name =~ "custom_.*" and last_seen_hours > 24'
%{ endif ~}

  # Label policy enforcement
  filter/label_policy:
    error_mode: ignore
    traces:
      span:
%{ for label in required_labels ~}
        # Drop spans missing required label: ${label}
        - 'resource.attributes["${label}"] == nil'
%{ endfor ~}
        
        # Drop spans with invalid environment values
%{ if length(allowed_environments) > 0 ~}
        - 'resource.attributes["environment"] != nil and not (resource.attributes["environment"] in [%{ for env in allowed_environments ~}"${env}"%{ if env != allowed_environments[length(allowed_environments)-1] ~}, %{ endif ~}%{ endfor ~}])'
%{ endif ~}
        
    metrics:
      metric:
%{ for label in required_labels ~}
        # Drop metrics missing required label: ${label}
        - 'resource.attributes["${label}"] == nil'
%{ endfor ~}

  # Data retention enforcement
  transform/retention:
    trace_statements:
      # Add retention metadata
      - set(attributes["retention.policy"], "standard")
      - set(attributes["retention.expires_at"], unix_timestamp() + ${retention_days} * 86400)
      
      # Mark high-priority data for extended retention
      - set(attributes["retention.policy"], "extended") where attributes["business.priority"] == "critical"
      - set(attributes["retention.expires_at"], unix_timestamp() + ${retention_days * 2} * 86400) where attributes["business.priority"] == "critical"
      
      # Mark debug data for short retention
      - set(attributes["retention.policy"], "short") where attributes["log.level"] == "DEBUG"
      - set(attributes["retention.expires_at"], unix_timestamp() + 7 * 86400) where attributes["log.level"] == "DEBUG"

  # Grok AI-powered processor for intelligent recommendations
%{ if enable_grok_processor ~}
  grok_recommender:
    api_key: $${env:GROK_API_KEY}
    max_sample_size: 100
    sampling_interval: 5m
    
    # Policy enforcement
    required_labels:
%{ for label in required_labels ~}
      - "${label}"
%{ endfor ~}
    
    # Auto-apply recommendations
    auto_apply_filters: true
    max_filter_rules: 50
    
    # Fallback behavior
    fallback_to_static: true
    
    # Cost optimization settings
    enable_cost_analysis: ${enable_cost_optimization}
    cost_threshold_percentage: 20  # Alert if cost reduction potential > 20%
    
    # Security settings
    enable_security_analysis: ${enable_security_compliance}
    anonymize_sensitive_data: ${enable_pii_filtering}
%{ endif ~}

  # Final batching processor
  batch:
    send_batch_size: 1024
    timeout: 5s
    send_batch_max_size: 2048

# Service pipeline configuration
service:
  telemetry:
    logs:
      level: ${log_level}
    metrics:
      address: 0.0.0.0:8888
      level: detailed
  
  pipelines:
    traces:
      receivers: [otlp]
      processors: [
        memory_limiter,
        resourcedetection,
        attributes/compliance,
%{ if enable_pii_filtering ~}
        attributes/pii_filter,
%{ endif ~}
%{ if enable_security_compliance ~}
        filter/security_compliance,
%{ endif ~}
%{ if enable_cost_optimization ~}
        filter/cost_optimization,
%{ endif ~}
        filter/label_policy,
        transform/retention,
%{ if enable_grok_processor ~}
        grok_recommender,
%{ endif ~}
        batch
      ]
      exporters: [otlp/downstream, debug]
    
    metrics:
      receivers: [otlp, prometheus]
      processors: [
        memory_limiter,
        resourcedetection,
        attributes/compliance,
%{ if enable_security_compliance ~}
        filter/security_compliance,
%{ endif ~}
%{ if enable_cost_optimization ~}
        filter/cost_optimization,
%{ endif ~}
        filter/label_policy,
        batch
      ]
      exporters: [otlp/downstream, debug]
    
    logs:
      receivers: [otlp]
      processors: [
        memory_limiter,
        resourcedetection,
        attributes/compliance,
%{ if enable_pii_filtering ~}
        attributes/pii_filter,
%{ endif ~}
%{ if enable_security_compliance ~}
        filter/security_compliance,
%{ endif ~}
        filter/label_policy,
        batch
      ]
      exporters: [otlp/downstream, debug]