{{/*
Pod template spec
*/}}
{{- define "hwl.pod" -}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end -}}
serviceAccountName: {{ include "hwl.serviceAccountName" . }}
{{- if (.Values.shareProcessNamespace) }}
shareProcessNamespace: true
{{- end }}
securityContext:
    {{- toYaml .Values.podSecurityContext | nindent 2}}
{{ if .Values.hostNetwork.enabled }}
hostNetwork: true
{{- end }}
{{- if .Values.addons.init.enabled }}
initContainers:
  {{- include "hwl.init.container" . | nindent 2 }}
{{- end }}
containers:
  {{- /* If enabled, VPN sidecar needs to start first */}}
  {{- if .Values.addons.vpn.enabled }}
  {{- include "hwl.gluetun.sidecar" . | nindent 2 }}
  {{- end }}
  {{- /* If enabled, Postgres database sidecar */}}
  {{- if .Values.addons.postgres.enabled }}
  {{- include "hwl.postgres.sidecar" . | nindent 2 }}
  {{- end }}
  {{- /* Extra sidecar containers */}}
  {{- range .Values.extraContainers }}
  - {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- /* Main application container */}}
  - name: {{ .Chart.Name }}
    {{- include "hwl.container" . | nindent 4 }}
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if or ((.Values.addons.vpn).enabled) ((.Values.addons.postgres).enabled) ((.Values.volumes).host) (.Values.extraVolumes) }}
volumes:
{{- with .Values.volumes }}
  {{- range .host }}
  - name: {{ .name }}
    {{- /* DEPRECATED: support for string based hostPath */}}
    {{- if kindIs "string" .hostPath }}
    hostPath:
      path: {{ .hostPath }}
    {{- else if kindIs "map" .hostPath }}
    hostPath:
      path: {{ .hostPath.path }}
      type: {{ .hostPath.type }}
    {{- end }}
  {{- end }}
{{- end }}
{{- if ((.Values.addons.vpn).enabled) }}
  {{- include "hwl.gluetun.volumes" . | nindent 2 }}
{{- end }}
{{- if ((.Values.addons.postgres).enabled) }}
  {{- include "hwl.postgres.volumes" . | nindent 2 }}
{{- end }}
{{- range .Values.extraVolumes }}
  - {{- toYaml . | nindent 4 }}
{{- end }}
{{- end }}
{{- end }}
