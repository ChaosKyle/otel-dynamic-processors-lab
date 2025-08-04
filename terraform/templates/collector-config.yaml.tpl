# OpenTelemetry Collector Configuration
# This configuration sets up the collector to receive telemetry data and forward it to the processor

receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
        cors:
          allowed_origins:
            - "http://*"
            - "https://*"

  # Prometheus metrics receiver
%{ if enable_metrics ~}
  prometheus:
    config:
      scrape_configs:
        - job_name: 'otel-collector'
          scrape_interval: 30s
          static_configs:
            - targets: ['0.0.0.0:8888']
%{ endif ~}

  # Host metrics receiver for infrastructure monitoring
  hostmetrics:
    collection_interval: 30s
    scrapers:
      cpu:
        metrics:
          system.cpu.utilization:
            enabled: true
      disk:
        metrics:
          system.disk.operations:
            enabled: true
          system.disk.io:
            enabled: true
      filesystem:
        metrics:
          system.filesystem.utilization:
            enabled: true
      memory:
        metrics:
          system.memory.utilization:
            enabled: true
      network:
        metrics:
          system.network.io:
            enabled: true
      process:
        mute_process_name_error: true
        mute_process_exe_error: true

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

  # Basic attribute processor for initial labeling
  attributes:
    actions:
      # Add collector metadata
      - key: collector.name
        value: "otel-collector"
        action: insert
      - key: collector.version
        value: "v0.89.0"
        action: insert
      - key: processing.stage
        value: "ingestion"
        action: insert
      - key: environment
        value: "${environment}"
        action: insert

  # Sampling processor to reduce load
  probabilistic_sampler:
    sampling_percentage: 100  # Adjust based on environment

  # Batch processor for efficient export
  batch:
    send_batch_size: 1024
    timeout: 5s
    send_batch_max_size: 2048

exporters:
  # Forward to processor for advanced filtering
  otlp/processor:
    endpoint: "otel-processor-service:4317"
    tls:
      insecure: true
    headers:
      "x-collector-stage": "ingestion"
      "x-environment": "${environment}"

  # Debug exporter for troubleshooting
  debug:
    verbosity: basic
    sampling_initial: 2
    sampling_thereafter: 500

%{ if enable_metrics ~}
  # Direct export to Grafana Cloud for collector metrics
  otlp/grafana_cloud:
    endpoint: "${grafana_cloud_prometheus_url}"
    headers:
      authorization: "Basic $${env:GRAFANA_CLOUD_INSTANCE_ID}:$${env:GRAFANA_CLOUD_API_KEY}"
%{ endif ~}

extensions:
  health_check:
    endpoint: 0.0.0.0:13133

  pprof:
    endpoint: 0.0.0.0:1777

  zpages:
    endpoint: 0.0.0.0:55679

service:
  telemetry:
    logs:
      level: ${log_level}
    metrics:
      address: 0.0.0.0:8888
      level: detailed

  extensions: [health_check, pprof, zpages]

  pipelines:
%{ if enable_tracing ~}
    traces:
      receivers: [otlp]
      processors: [
        memory_limiter,
        resourcedetection,
        attributes,
        probabilistic_sampler,
        batch
      ]
      exporters: [otlp/processor, debug]
%{ endif ~}

%{ if enable_metrics ~}
    metrics:
      receivers: [otlp, prometheus, hostmetrics]
      processors: [
        memory_limiter,
        resourcedetection,
        attributes,
        batch
      ]
      exporters: [otlp/processor, otlp/grafana_cloud, debug]
%{ endif ~}

%{ if enable_logging ~}
    logs:
      receivers: [otlp]
      processors: [
        memory_limiter,
        resourcedetection,
        attributes,
        batch
      ]
      exporters: [otlp/processor, debug]
%{ endif ~}