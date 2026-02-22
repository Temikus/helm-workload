{{/*
Postgres addon labels
*/}}
{{- define "hwl.postgres.labels" -}}
{{ include "hwl.labels" . }}
app.kubernetes.io/component: postgres
{{- end }}

{{/*
Postgres addon selector labels
*/}}
{{- define "hwl.postgres.selectorLabels" -}}
{{ include "hwl.selectorLabels" . }}
app.kubernetes.io/component: postgres
{{- end }}

{{/*
Postgres standalone Deployment
*/}}
{{- define "hwl.postgres.deployment" -}}
{{- $postgres := .Values.addons.postgres -}}
{{- if $postgres.enabled -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "hwl.fullname" . }}-postgres
  labels:
    {{- include "hwl.postgres.labels" . | nindent 4 }}
spec:
  replicas: 1
  selector:
    matchLabels:
      {{- include "hwl.postgres.selectorLabels" . | nindent 6 }}
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        {{- include "hwl.postgres.selectorLabels" . | nindent 8 }}
    spec:
      {{- if $postgres.securityContext }}
      {{- if $postgres.securityContext.fsGroup }}
      securityContext:
        fsGroup: {{ $postgres.securityContext.fsGroup }}
      {{- end }}
      {{- end }}
      containers:
        - name: postgres
          {{- with $postgres.image }}
          image: {{ .repository | default "postgres" }}:{{ .tag | default "15-alpine" }}
          imagePullPolicy: {{ .pullPolicy | default "IfNotPresent" }}
          {{- end }}
          {{- if and $postgres.securityContext (or $postgres.securityContext.runAsUser $postgres.securityContext.runAsGroup) }}
          securityContext:
            {{- if $postgres.securityContext.runAsUser }}
            runAsUser: {{ $postgres.securityContext.runAsUser }}
            {{- end }}
            {{- if $postgres.securityContext.runAsGroup }}
            runAsGroup: {{ $postgres.securityContext.runAsGroup }}
            {{- end }}
          {{- end }}
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
            {{- toYaml . | nindent 12 }}
            {{- end }}
          ports:
            - name: postgres
              containerPort: 5432
              protocol: TCP
          {{- with $postgres.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- if or $postgres.persistence.enabled $postgres.persistence.existingClaim }}
          volumeMounts:
            - name: postgres-data
              mountPath: /var/lib/postgresql/data
              subPath: {{ $postgres.persistence.subPath | default "data" }}
          {{- end }}
          {{- if $postgres.livenessProbe }}
          livenessProbe:
            {{- toYaml $postgres.livenessProbe | nindent 12 }}
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
            {{- toYaml $postgres.readinessProbe | nindent 12 }}
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
      {{- if or $postgres.persistence.enabled $postgres.persistence.existingClaim }}
      volumes:
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
      {{- with $postgres.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $postgres.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $postgres.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
{{- end }}

{{/*
Postgres Service
*/}}
{{- define "hwl.postgres.service" -}}
{{- $postgres := .Values.addons.postgres -}}
{{- if $postgres.enabled -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "hwl.fullname" . }}-postgres
  labels:
    {{- include "hwl.postgres.labels" . | nindent 4 }}
spec:
  type: {{ ($postgres.service).type | default "ClusterIP" }}
  ports:
    - port: {{ ($postgres.service).port | default 5432 }}
      targetPort: postgres
      protocol: TCP
      name: postgres
  selector:
    {{- include "hwl.postgres.selectorLabels" . | nindent 4 }}
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
