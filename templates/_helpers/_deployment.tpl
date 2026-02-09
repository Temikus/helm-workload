{{/*
Deployment template
*/}}
{{- define "hwl.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "hwl.fullname" . }}
  labels:
    {{- include "hwl.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "hwl.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        kubectl.kubernetes.io/default-container: {{ .Chart.Name }}
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "hwl.selectorLabels" . | nindent 8 }}
    spec:
      {{- include "hwl.pod" . | nindent 6 }}
{{- end }}
