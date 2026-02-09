{{/*
Common naming helpers
*/}}
{{- define "hwl.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "hwl.fullname" -}}
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
{{- define "hwl.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "hwl.labels" -}}
helm.sh/chart: {{ include "hwl.chart" . }}
{{ include "hwl.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "hwl.selectorLabels" -}}
app.kubernetes.io/name: {{ include "hwl.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service Account Name
*/}}
{{- define "hwl.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "hwl.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Environment ConfigMap Name
*/}}
{{- define "hwl.env-configMapName" -}}
{{- default (include "hwl.fullname" .) }}
{{- end }}

{{/*
Default Service Name for Ingress
*/}}
{{- define "hwl.defaultServiceName" -}}
{{- if and .Values.ports (kindIs "slice" .Values.ports) }}
  {{- $prefix := (index .Values.ports 0).service.name | default (index .Values.ports 0).name }}
  {{- $prefix}}-{{ include "hwl.fullname" . }}
{{- else }}
  {{- include "hwl.fullname" . }}
{{- end }}
{{- end }}

{{/*
Default Service Port for Ingress
*/}}
{{- define "hwl.defaultServicePort" -}}
{{- if and .Values.ports (kindIs "slice" .Values.ports) }}
  {{- (index .Values.ports 0).service.port | default (index .Values.ports 0).port }}
{{- else }}
  {{- fail "Unable to determine default port" }}
{{- end }}
{{- end }}
