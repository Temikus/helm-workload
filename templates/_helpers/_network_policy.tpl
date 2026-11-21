{{/*
NetworkPolicy template
Restricts ingress traffic to the pod based on configured rules, and egress
too when egress rules are given.
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
    {{- include "hwl.mainPodSelector" . | nindent 4 }}
  policyTypes:
    - Ingress
{{- with $np.egress }}
    - Egress
  egress:
    {{- toYaml . | nindent 4 }}
{{- end }}
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
{{- /* A rule with no ports allows every port, so no ports means deny-all. */}}
{{- else if and $np.allowPortsIngress .Values.ports }}
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
