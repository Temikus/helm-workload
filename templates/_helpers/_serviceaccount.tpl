{{/*
ServiceAccount template
*/}}
{{- define "hwl.serviceaccount" -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "hwl.serviceAccountName" . }}
  labels:
    {{- include "hwl.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}