{{/*
Ingress template
*/}}
{{- define "hwl.ingress" -}}
{{- $fullName := include "hwl.fullname" . -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $fullName }}
  labels:
    {{- include "hwl.labels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .Values.ingress.className }}
  ingressClassName: {{ .Values.ingress.className }}
  {{- end }}
  {{- if .Values.ingress.tls }}
  tls:
    {{- range .Values.ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- if .paths }}
            {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                {{- if .backend }}
                {{- toYaml .backend.service | nindent 16 }}
                {{- else}}
                name: {{ include "hwl.defaultServiceName" $ }}
                port:
                  number: {{ include "hwl.defaultServicePort" $ }}
              {{- end }}
          {{- end }}
          {{- else }}
          - path: '/'
            pathType: ImplementationSpecific
            backend:
              service:
                name: {{ include "hwl.defaultServiceName" $ }}
                port:
                  number: {{ include "hwl.defaultServicePort" $ }}
          {{- end }}
    {{- end }}
{{- end }}