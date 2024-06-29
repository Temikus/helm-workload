{{/*
Error out if there's no release name set
*/}}
{{- if .Release.Name | eq "" -}}
  {{- fail "value for .Release.Name is not set" }}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "workload.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "workload.fullname" -}}
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
{{- define "workload.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "workload.labels" -}}
helm.sh/chart: {{ include "workload.chart" . }}
{{ include "workload.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "workload.selectorLabels" -}}
app.kubernetes.io/name: {{ include "workload.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "workload.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "workload.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the configMap to use
*/}}
{{- define "workload.env-configMapName" -}}
{{- default (include "workload.fullname" .) }}
{{- end }}

{{/*
  Create the name for the default ingress service to use
*/}}
{{- define "workload.defaultServiceName" -}}
  {{- if .Values.ports }}
    {{- $prefix := (index .Values.ports 0).service.name | default (index .Values.ports 0).name }}
    {{- $prefix}}-{{ include "workload.fullname" . }}
  {{- else }}
    {{- include "workload.fullname" . }}
  {{- end }}
{{- end }}

{{/*
  Create the name for the default ingress service to use
*/}}
{{- define "workload.defaultServicePort" -}}
  {{- if .Values.ports }}
    {{- (index .Values.ports 0).service.port | default (index .Values.ports 0).port }}
  {{- else }}
    {{- fail "Unable to determine default port" }}
  {{- end }}
{{- end }}
