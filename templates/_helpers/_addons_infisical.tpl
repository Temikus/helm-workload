{{/*
Infisical addon: managed Secret name
*/}}
{{- define "hwl.infisical.managedSecretName" -}}
{{- .Values.addons.infisical.managedSecretName | default (printf "%s-infisical" (include "hwl.fullname" .)) -}}
{{- end }}

{{/*
Infisical addon: whether the managed Secret is injected into the main container's envFrom
*/}}
{{- define "hwl.infisical.injectEnvFrom" -}}
{{- $inf := (.Values.addons.infisical | default dict) -}}
{{- if and $inf.enabled (ne $inf.injectEnvFrom false) -}}true{{- end -}}
{{- end }}

{{/*
Infisical addon: workload annotations.
The operator's auto-reload restarts workloads that consume the managed Secret,
so no extra reloader dependency is needed.
*/}}
{{- define "hwl.infisical.annotations" -}}
{{- $inf := (.Values.addons.infisical | default dict) -}}
{{- if and $inf.enabled (ne $inf.autoReload false) -}}
secrets.infisical.com/auto-reload: "true"
{{- end -}}
{{- end }}

{{/*
InfisicalSecret CR (secrets-operator). Universal-auth only; the credentials
Secret (clientId/clientSecret) is referenced by name, never created here.
*/}}
{{- define "hwl.infisical.secret" -}}
{{- $inf := .Values.addons.infisical -}}
{{- if $inf.enabled -}}
{{- if and $inf.hostAPI (not (contains "/api" $inf.hostAPI)) -}}
{{- fail (printf "addons.infisical.hostAPI must include the API path, e.g. https://infisical.example.com/api (got %q)" $inf.hostAPI) -}}
{{- end -}}
apiVersion: secrets.infisical.com/v1alpha1
kind: InfisicalSecret
metadata:
  name: {{ include "hwl.fullname" . }}-infisical
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "hwl.labels" . | nindent 4 }}
spec:
  {{- if $inf.hostAPI }}
  hostAPI: {{ $inf.hostAPI | quote }}
  {{- end }}
  resyncInterval: {{ $inf.resyncInterval | default 60 }}
  authentication:
    universalAuth:
      credentialsRef:
        secretName: {{ $inf.credentialsSecret | default "infisical-universal-auth" }}
        secretNamespace: {{ $inf.credentialsSecretNamespace | default .Release.Namespace }}
      secretsScope:
        projectSlug: {{ required "addons.infisical.projectSlug is required when addons.infisical.enabled is true" $inf.projectSlug | quote }}
        envSlug: {{ required "addons.infisical.envSlug is required when addons.infisical.enabled is true" $inf.envSlug | quote }}
        secretsPath: {{ $inf.secretsPath | default "/" | quote }}
        {{- if $inf.recursive }}
        recursive: true
        {{- end }}
  managedKubeSecretReferences:
    - secretName: {{ include "hwl.infisical.managedSecretName" . }}
      secretNamespace: {{ .Release.Namespace }}
      creationPolicy: {{ $inf.creationPolicy | default "Owner" }}
      template:
        includeAllSecrets: {{ ne $inf.includeAllSecrets false }}
        {{- with $inf.keys }}
        data:
          {{- range $env, $key := . }}
          {{ $env }}: {{ printf "{{ .%s.Value }}" $key | quote }}
          {{- end }}
        {{- end }}
{{- end }}
{{- end }}
