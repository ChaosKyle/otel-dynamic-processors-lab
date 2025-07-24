{{/*
Expand the name of the chart.
*/}}
{{- define "alloy-dynamic-processors.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "alloy-dynamic-processors.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "alloy-dynamic-processors.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "alloy-dynamic-processors.labels" -}}
helm.sh/chart: {{ include "alloy-dynamic-processors.chart" . }}
{{ include "alloy-dynamic-processors.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "alloy-dynamic-processors.selectorLabels" -}}
app.kubernetes.io/name: {{ include "alloy-dynamic-processors.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "alloy-dynamic-processors.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "alloy-dynamic-processors.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the Grafana Cloud secret name
*/}}
{{- define "alloy-dynamic-processors.grafanaCloudSecretName" -}}
{{- if .Values.grafanaCloud.credentials.existingSecret }}
{{- .Values.grafanaCloud.credentials.existingSecret }}
{{- else }}
{{- printf "%s-grafana-cloud" (include "alloy-dynamic-processors.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Alloy image
*/}}
{{- define "alloy-dynamic-processors.image" -}}
{{- $registry := .Values.alloy.image.registry | default .Values.global.imageRegistry -}}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry .Values.alloy.image.repository (.Values.alloy.image.tag | default .Chart.AppVersion) }}
{{- else }}
{{- printf "%s:%s" .Values.alloy.image.repository (.Values.alloy.image.tag | default .Chart.AppVersion) }}
{{- end }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "alloy-dynamic-processors.annotations" -}}
{{- with .Values.commonAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Alloy configuration based on type
*/}}
{{- define "alloy-dynamic-processors.config" -}}
{{- if .Values.alloy.config.custom }}
{{- .Values.alloy.config.custom }}
{{- else if eq .Values.alloy.config.type "basic" }}
{{- .Files.Get "configs/basic-template.alloy" }}
{{- else if eq .Values.alloy.config.type "production" }}
{{- .Files.Get "configs/grafana-cloud-production.alloy" }}
{{- else }}
{{- .Files.Get "configs/enhanced-with-sort.alloy" }}
{{- end }}
{{- end }}

{{/*
Environment variables for Alloy
*/}}
{{- define "alloy-dynamic-processors.env" -}}
- name: APP_NAME
  value: {{ .Values.alloy.config.env.APP_NAME | quote }}
- name: APP_VERSION
  value: {{ .Values.alloy.config.env.APP_VERSION | quote }}
- name: ENVIRONMENT
  value: {{ .Values.alloy.config.env.ENVIRONMENT | quote }}
- name: SERVICE_NAMESPACE
  value: {{ .Values.alloy.config.env.SERVICE_NAMESPACE | quote }}
- name: LOG_LEVEL
  value: {{ .Values.alloy.config.env.LOG_LEVEL | quote }}
- name: K8S_CLUSTER_NAME
  value: {{ .Values.alloy.config.env.K8S_CLUSTER_NAME | quote }}
- name: CLOUD_REGION
  value: {{ .Values.alloy.config.env.CLOUD_REGION | quote }}
- name: ENABLE_RESOURCE_DETECTION
  value: {{ .Values.alloy.config.env.ENABLE_RESOURCE_DETECTION | quote }}
- name: DETECT_DOCKER
  value: {{ .Values.alloy.config.env.DETECT_DOCKER | quote }}
- name: DETECT_SYSTEM
  value: {{ .Values.alloy.config.env.DETECT_SYSTEM | quote }}
- name: DETECT_PROCESS
  value: {{ .Values.alloy.config.env.DETECT_PROCESS | quote }}
- name: NODE_NAME
  valueFrom:
    fieldRef:
      fieldPath: spec.nodeName
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: POD_NAMESPACE
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace
{{- if .Values.grafanaCloud.enabled }}
- name: GRAFANA_CLOUD_INSTANCE_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "alloy-dynamic-processors.grafanaCloudSecretName" . }}
      key: instance-id
- name: GRAFANA_CLOUD_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "alloy-dynamic-processors.grafanaCloudSecretName" . }}
      key: api-key
- name: GRAFANA_CLOUD_PROMETHEUS_URL
  valueFrom:
    secretKeyRef:
      name: {{ include "alloy-dynamic-processors.grafanaCloudSecretName" . }}
      key: prometheus-url
- name: GRAFANA_CLOUD_TEMPO_URL
  valueFrom:
    secretKeyRef:
      name: {{ include "alloy-dynamic-processors.grafanaCloudSecretName" . }}
      key: tempo-url
- name: GRAFANA_CLOUD_LOKI_URL
  valueFrom:
    secretKeyRef:
      name: {{ include "alloy-dynamic-processors.grafanaCloudSecretName" . }}
      key: loki-url
{{- end }}
{{- end }}