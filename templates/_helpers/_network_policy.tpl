{{/*
NetworkPolicy template
Restricts ingress traffic to the pod based on configured rules.
*/}}
{{- define "hwl.networkPolicy" -}}
{{- $np := .Values.networkPolicy -}}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "hwl.fullname" . }}
  labels:
    {{- include "hwl.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "hwl.selectorLabels" . | nindent 6 }}
  policyTypes:
    - Ingress
{{- if $np.ingress }}
  ingress:
    {{- range $np.ingress }}
    - {{- if .ports }}
      ports:
        {{- range .ports }}
        - protocol: {{ .protocol | default "TCP" }}
          port: {{ .port }}
        {{- end }}
      {{- end }}
      {{- if .from }}
      from:
        {{- toYaml .from | nindent 8 }}
      {{- end }}
    {{- end }}
{{- else if $np.allowPortsIngress }}
  ingress:
    - ports:
    {{- range .Values.ports }}
        - protocol: {{ .protocol | default "TCP" }}
          port: {{ .port }}
    {{- end }}
{{- else }}
  ingress: []
{{- end }}
{{- end }}
