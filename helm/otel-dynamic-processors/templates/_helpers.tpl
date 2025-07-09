{{/*
Expand the name of the chart.
*/}}
{{- define "otel-dynamic-processors.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "otel-dynamic-processors.fullname" -}}
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
{{- define "otel-dynamic-processors.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "otel-dynamic-processors.labels" -}}
helm.sh/chart: {{ include "otel-dynamic-processors.chart" . }}
{{ include "otel-dynamic-processors.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "otel-dynamic-processors.selectorLabels" -}}
app.kubernetes.io/name: {{ include "otel-dynamic-processors.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Collector specific names and labels
*/}}
{{- define "otel-dynamic-processors.collector.fullname" -}}
{{- printf "%s-%s" (include "otel-dynamic-processors.fullname" .) .Values.collector.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "otel-dynamic-processors.collector.labels" -}}
{{ include "otel-dynamic-processors.labels" . }}
app.kubernetes.io/component: collector
{{- end }}

{{- define "otel-dynamic-processors.collector.selectorLabels" -}}
{{ include "otel-dynamic-processors.selectorLabels" . }}
app.kubernetes.io/component: collector
{{- end }}

{{- define "otel-dynamic-processors.collector.image" -}}
{{- $registry := .Values.global.imageRegistry | default .Values.collector.image.registry -}}
{{- $repository := .Values.collector.image.repository -}}
{{- $tag := .Values.collector.image.tag | default .Chart.AppVersion -}}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- else }}
{{- printf "%s:%s" $repository $tag }}
{{- end }}
{{- end }}

{{/*
Processor specific names and labels
*/}}
{{- define "otel-dynamic-processors.processor.fullname" -}}
{{- printf "%s-%s" (include "otel-dynamic-processors.fullname" .) .Values.processor.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "otel-dynamic-processors.processor.labels" -}}
{{ include "otel-dynamic-processors.labels" . }}
app.kubernetes.io/component: processor
{{- end }}

{{- define "otel-dynamic-processors.processor.selectorLabels" -}}
{{ include "otel-dynamic-processors.selectorLabels" . }}
app.kubernetes.io/component: processor
{{- end }}

{{- define "otel-dynamic-processors.processor.image" -}}
{{- $registry := .Values.global.imageRegistry | default .Values.processor.image.registry -}}
{{- $repository := .Values.processor.image.repository -}}
{{- $tag := .Values.processor.image.tag | default .Chart.AppVersion -}}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- else }}
{{- printf "%s:%s" $repository $tag }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "otel-dynamic-processors.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "otel-dynamic-processors.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the cluster role to use
*/}}
{{- define "otel-dynamic-processors.clusterRoleName" -}}
{{- printf "%s-cluster-role" (include "otel-dynamic-processors.fullname" .) }}
{{- end }}

{{/*
Create the name of the cluster role binding to use
*/}}
{{- define "otel-dynamic-processors.clusterRoleBindingName" -}}
{{- printf "%s-cluster-role-binding" (include "otel-dynamic-processors.fullname" .) }}
{{- end }}

{{/*
Return the appropriate apiVersion for HorizontalPodAutoscaler
*/}}
{{- define "otel-dynamic-processors.hpa.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "autoscaling/v2" -}}
{{- print "autoscaling/v2" -}}
{{- else -}}
{{- print "autoscaling/v2beta2" -}}
{{- end -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for PodDisruptionBudget
*/}}
{{- define "otel-dynamic-processors.pdb.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "policy/v1" -}}
{{- print "policy/v1" -}}
{{- else -}}
{{- print "policy/v1beta1" -}}
{{- end -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for NetworkPolicy
*/}}
{{- define "otel-dynamic-processors.networkPolicy.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "networking.k8s.io/v1" -}}
{{- print "networking.k8s.io/v1" -}}
{{- else -}}
{{- print "networking.k8s.io/v1beta1" -}}
{{- end -}}
{{- end -}}

{{/*
Return the target Kubernetes version
*/}}
{{- define "otel-dynamic-processors.kubeVersion" -}}
{{- if .Values.global.kubeVersion }}
{{- .Values.global.kubeVersion }}
{{- else }}
{{- .Capabilities.KubeVersion.Version }}
{{- end }}
{{- end }}

{{/*
Return the appropriate apiVersion for Ingress
*/}}
{{- define "otel-dynamic-processors.ingress.apiVersion" -}}
{{- if and (.Capabilities.APIVersions.Has "networking.k8s.io/v1") (semverCompare ">=1.19-0" (include "otel-dynamic-processors.kubeVersion" .)) -}}
{{- print "networking.k8s.io/v1" -}}
{{- else if .Capabilities.APIVersions.Has "networking.k8s.io/v1beta1" -}}
{{- print "networking.k8s.io/v1beta1" -}}
{{- else -}}
{{- print "extensions/v1beta1" -}}
{{- end -}}
{{- end -}}

{{/*
Return true if the Ingress is stable
*/}}
{{- define "otel-dynamic-processors.ingress.isStable" -}}
{{- eq (include "otel-dynamic-processors.ingress.apiVersion" .) "networking.k8s.io/v1" -}}
{{- end -}}

{{/*
Return true if the Ingress supports ingressClassName
*/}}
{{- define "otel-dynamic-processors.ingress.supportsIngressClassName" -}}
{{- or (eq (include "otel-dynamic-processors.ingress.apiVersion" .) "networking.k8s.io/v1") (and (eq (include "otel-dynamic-processors.ingress.apiVersion" .) "networking.k8s.io/v1beta1") (semverCompare ">=1.18-0" (include "otel-dynamic-processors.kubeVersion" .))) -}}
{{- end -}}

{{/*
Return true if the Ingress supports pathType
*/}}
{{- define "otel-dynamic-processors.ingress.supportsPathType" -}}
{{- or (eq (include "otel-dynamic-processors.ingress.apiVersion" .) "networking.k8s.io/v1") (and (eq (include "otel-dynamic-processors.ingress.apiVersion" .) "networking.k8s.io/v1beta1") (semverCompare ">=1.18-0" (include "otel-dynamic-processors.kubeVersion" .))) -}}
{{- end -}}