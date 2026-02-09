{{/*
Environment ConfigMap template
*/}}
{{- define "hwl.env-configmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "hwl.env-configMapName" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "hwl.labels" . | nindent 4 }}
data:
  {{- toYaml .Values.env | nindent 2 }}
{{- end }}