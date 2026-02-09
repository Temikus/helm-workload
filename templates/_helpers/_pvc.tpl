{{/*
PVC template
*/}}
{{- define "hwl.pvc" -}}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "hwl.fullname" . }}
  labels:
    {{- include "hwl.labels" . | nindent 4 }}
    {{- with .Values.persistence.extraPvcLabels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with .Values.persistence.annotations  }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.persistence.finalizers  }}
  finalizers:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  accessModes:
    {{- range .Values.persistence.accessModes }}
    - {{ . | quote }}
    {{- end }}
  resources:
    requests:
      storage: {{ .Values.persistence.size | quote }}
  {{- with .Values.persistence.storageClassName }}
  storageClassName: {{ . }}
  {{- end }}
  {{- with .Values.persistence.selectorLabels }}
  selector:
    matchLabels:
    {{- toYaml . | nindent 6 }}
  {{- end }}
{{- end }}

{{/*
Return the PVC name to use
*/}}
{{- define "hwl.pvcName" -}}
{{- if .Values.persistence.existingClaim }}
{{- .Values.persistence.existingClaim }}
{{- else }}
{{- include "hwl.fullname" . }}
{{- end }}
{{- end }}