{{/*
Postgres database sidecar container configuration
*/}}
{{- define "hwl.postgres.sidecar" -}}
{{- $postgres := .Values.addons.postgres -}}
{{- if $postgres.enabled -}}
- name: postgres
  {{- with $postgres.image }}
  image: {{ .repository | default "postgres" }}:{{ .tag | default "15-alpine" }}
  imagePullPolicy: {{ .pullPolicy | default "IfNotPresent" }}
  {{- end }}
  securityContext:
    runAsUser: 999
    runAsGroup: 999
    fsGroup: 999
  env:
    - name: POSTGRES_USER
      value: {{ required "PostgreSQL username is required" $postgres.auth.username | quote }}
    {{- if $postgres.auth.existingSecret }}
    - name: POSTGRES_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ $postgres.auth.existingSecret }}
          key: {{ $postgres.auth.existingSecretKey | default "postgres-password" }}
    {{- else }}
    - name: POSTGRES_PASSWORD
      value: {{ required "PostgreSQL password is required" $postgres.auth.password | quote }}
    {{- end }}
    {{- if $postgres.auth.database }}
    - name: POSTGRES_DB
      value: {{ $postgres.auth.database | quote }}
    {{- end }}
    {{- with $postgres.additionalEnv }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  ports:
    - name: postgres
      containerPort: 5432
      protocol: TCP
  {{- with $postgres.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if or $postgres.persistence.enabled $postgres.persistence.existingClaim }}
  volumeMounts:
    - name: postgres-data
      mountPath: /var/lib/postgresql/data
      subPath: {{ $postgres.persistence.subPath | default "data" }}
  {{- end }}
  {{- if $postgres.livenessProbe }}
  livenessProbe:
    {{- toYaml $postgres.livenessProbe | nindent 4 }}
  {{- else }}
  livenessProbe:
    exec:
      command:
        - pg_isready
        - -U
        - {{ $postgres.auth.username | quote }}
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 6
  {{- end }}
  {{- if $postgres.readinessProbe }}
  readinessProbe:
    {{- toYaml $postgres.readinessProbe | nindent 4 }}
  {{- else }}
  readinessProbe:
    exec:
      command:
        - pg_isready
        - -U
        - {{ $postgres.auth.username | quote }}
    initialDelaySeconds: 5
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 6
  {{- end }}
{{- end }}
{{- end }}

{{/*
Postgres volume configurations
*/}}
{{- define "hwl.postgres.volumes" -}}
{{- $postgres := .Values.addons.postgres -}}
{{- if and $postgres.enabled (or $postgres.persistence.enabled $postgres.persistence.existingClaim) }}
- name: postgres-data
  {{- if $postgres.persistence.existingClaim }}
  persistentVolumeClaim:
    claimName: {{ $postgres.persistence.existingClaim }}
  {{- else if $postgres.persistence.enabled }}
  persistentVolumeClaim:
    claimName: {{ include "hwl.fullname" . }}-postgres
  {{- else }}
  emptyDir: {}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Postgres PVC definition
*/}}
{{- define "hwl.postgres.pvc" -}}
{{- $postgres := .Values.addons.postgres -}}
{{- if and $postgres.enabled $postgres.persistence.enabled (not $postgres.persistence.existingClaim) }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "hwl.fullname" . }}-postgres
  labels:
    {{- include "hwl.labels" . | nindent 4 }}
spec:
  accessModes:
    - {{ $postgres.persistence.accessMode | default "ReadWriteOnce" }}
  {{- if $postgres.persistence.storageClass }}
  {{- if (eq "-" $postgres.persistence.storageClass) }}
  storageClassName: ""
  {{- else }}
  storageClassName: {{ $postgres.persistence.storageClass }}
  {{- end }}
  {{- end }}
  resources:
    requests:
      storage: {{ $postgres.persistence.size | default "8Gi" }}
{{- end }}
{{- end }}