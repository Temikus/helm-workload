{{/*
StatefulSet template
*/}}
{{- define "hwl.statefulset" -}}
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ include "hwl.fullname" . }}
  labels:
    {{- include "hwl.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  {{- with .Values.strategy }}
  updateStrategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "hwl.selectorLabels" . | nindent 6 }}
  serviceName: {{ include "hwl.fullname" . }}-headless
  template:
    metadata:
      labels:
        {{- include "hwl.selectorLabels" . | nindent 8 }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      annotations:
        kubectl.kubernetes.io/default-container: {{ .Chart.Name }}
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- include "hwl.pod" . | nindent 6 }}
  {{- if .Values.persistence.enabled }}
  volumeClaimTemplates:
    - apiVersion: v1
      kind: PersistentVolumeClaim
      metadata:
        name: storage
        {{- with .Values.persistence.extraPvcLabels }}
        labels:
          {{- toYaml . | nindent 10 }}
        {{- end }}
      spec:
        accessModes: {{ .Values.persistence.accessModes }}
        storageClassName: {{ .Values.persistence.storageClassName }}
        resources:
          requests:
            storage: {{ .Values.persistence.size }}
      {{- with .Values.persistence.selectorLabels }}
        selector:
          matchLabels:
          {{- toYaml . | nindent 10 }}
      {{- end }}
    {{- if .Values.persistence.extraVolumes }}
    {{- range .Values.persistence.extraVolumes }}
    - metadata:
        name: {{ .name }}
        {{- with .labels }}
        labels:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        {{- with .annotations }}
        annotations:
          {{- toYaml . | nindent 10 }}
        {{- end }}
      spec:
        accessModes: {{ .accessModes | default (list "ReadWriteOnce") }}
        {{- if .storageClassName }}
        storageClassName: {{ .storageClassName }}
        {{- end }}
        resources:
          requests:
            storage: {{ .size | quote }}
        {{- with .selectorLabels }}
        selector:
          matchLabels:
          {{- toYaml . | nindent 10 }}
        {{- end }}
    {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
