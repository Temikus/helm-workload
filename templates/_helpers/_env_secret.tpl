{{/*
Environment Secret template
*/}}
{{- define "hwl.env-secretName" -}}
{{ include "hwl.fullname" . }}-env
{{- end }}

{{- define "hwl.env-secret" -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "hwl.env-secretName" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "hwl.labels" . | nindent 4 }}
type: Opaque
stringData:
  {{- toYaml .Values.secretEnv | nindent 2 }}
{{- end }}
