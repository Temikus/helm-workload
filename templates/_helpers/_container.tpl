{{/*
Container template spec
*/}}
{{- define "hwl.container" -}}
securityContext:
  {{- toYaml .Values.securityContext | nindent 2 }}
image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
imagePullPolicy: {{ .Values.image.pullPolicy }}
ports:
  {{- range .Values.ports }}
  - name: {{ .name }}
    containerPort: {{ .port }}
    {{- if .protocol }}
    protocol: {{ .protocol }}
    {{- end }}
  {{- end }}
{{- if .Values.health }}
  {{- if or (and .Values.health.startupProbe.enabled (hasKey .Values.health.startupProbe "enabled")) (and .Values.health.startupProbe (not (hasKey .Values.health.startupProbe "enabled"))) }}
startupProbe:
    {{- omit .Values.health.startupProbe "enabled" | toYaml | nindent 2 }}
  {{- end }}
  {{- if or (and .Values.health.livenessProbe.enabled (hasKey .Values.health.livenessProbe "enabled")) (and .Values.health.livenessProbe (not (hasKey .Values.health.livenessProbe "enabled"))) }}
livenessProbe:
    {{- omit .Values.health.livenessProbe "enabled" | toYaml | nindent 2 }}
  {{- end }}
  {{- if or (and .Values.health.readinessProbe.enabled (hasKey .Values.health.readinessProbe "enabled")) (and .Values.health.readinessProbe (not (hasKey .Values.health.readinessProbe "enabled"))) }}
readinessProbe:
    {{- omit .Values.health.readinessProbe "enabled" | toYaml | nindent 2 }}
  {{- end }}
{{- end }}
{{- if .Values.command }}
command:
  {{- toYaml .Values.command | nindent 2 }}
{{- end }}
{{- /* Volume Mounts section */}}
volumeMounts:
{{- /* Handle persistence volume mount */}}
{{- if and .Values.persistence.enabled .Values.persistence.mountPath }}
  - name: storage
    mountPath: {{ .Values.persistence.mountPath }}
    {{- if .Values.persistence.subPath }}
    subPath: {{ .Values.persistence.subPath | quote }}
    {{- end }}
{{- end }}
{{- /* Handle extra persistence volumes mount */}}
{{- if and .Values.persistence.enabled .Values.persistence.extraVolumes }}
  {{- range .Values.persistence.extraVolumes }}
    {{- if .mountPath }}
  - name: {{ .name }}
    mountPath: {{ .mountPath }}
    {{- if .subPath }}
    subPath: {{ .subPath | quote }}
    {{- end }}
    {{- if .readOnly }}
    readOnly: {{ .readOnly }}
    {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- /* Handle host volumes - legacy format */}}
{{- range .Values.volumes.host }}
  - name: {{ .name }}
    mountPath: {{ .containerPath.path }}
{{- end }}
{{- /* Handle volumeMounts if directly specified */}}
{{- if .Values.volumeMounts }}
  {{- range .Values.volumeMounts }}
  - name: {{ .name }}
    mountPath: {{ .mountPath }}
    {{- if .subPath }}
    subPath: {{ .subPath }}
    {{- end }}
    {{- if .readOnly }}
    readOnly: {{ .readOnly }}
    {{- end }}
  {{- end }}
{{- end }}
{{- if .Values.env }}
envFrom:
  - configMapRef:
      name: {{ include "hwl.env-configMapName" . }}
{{- end }}
resources:
  {{- toYaml .Values.resources | nindent 2 }}
{{- end }}
