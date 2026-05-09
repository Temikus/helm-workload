{{/*
Service template
*/}}
{{- define "hwl.service" -}}
{{- range .Values._servicePorts }}
apiVersion: v1
kind: Service
metadata:
  {{/* Prefer override if set */}}
  {{- if .service.nameOverride -}}
  name: {{ .service.nameOverride }}
  {{/* Set service name if set*/}}
  {{- else if .service.name -}}
  name: {{ .service.name }}-{{ include "hwl.fullname" $ }}
  {{/* Otherwise set to port name */}}
  {{- else if .name -}}
  name: {{ .name }}-{{ include "hwl.fullname" $ }}
  {{- else -}}
  {{/* Otherwise default to workload name */}}
  name: {{ include "hwl.fullname" $ }}
  {{- end }}
  labels:
    {{- include "hwl.labels" $ | nindent 4 }}
spec:
  type: {{ default "ClusterIP" .service.type }}
  ports:
    - port: {{ default .port .service.port }}
      targetPort: {{ default .name .containerPortNameOverride }}
      protocol: {{ default "TCP" .protocol }}
      name: {{ default .name .service.name }}
  selector:
    {{- include "hwl.selectorLabels" $ | nindent 4 }}
---
{{- end }}
{{- end }}

{{/*
Extra services template — renders multi-port Service resources from .Values.extraServices
*/}}
{{- define "hwl.extraServices" -}}
{{- range .Values.extraServices }}
apiVersion: v1
kind: Service
metadata:
  name: {{ .name }}-{{ include "hwl.fullname" $ }}
  labels:
    {{- include "hwl.labels" $ | nindent 4 }}
  {{- with .annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ default "ClusterIP" .type }}
  ports:
    {{- range .ports }}
    - name: {{ .name }}
      port: {{ .port }}
      targetPort: {{ default .name .targetPort }}
      protocol: {{ default "TCP" .protocol }}
    {{- end }}
  selector:
    {{- include "hwl.selectorLabels" $ | nindent 4 }}
---
{{- end }}
{{- end }}
