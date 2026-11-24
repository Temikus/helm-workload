{{/*
PodMonitor template (Prometheus Operator)
Scrapes the main workload pods; the postgres addon pod is excluded.
*/}}
{{- define "hwl.podMonitor" -}}
{{- $pm := .Values.podMonitor -}}
{{- if not $pm.endpoints -}}
{{- fail "podMonitor.endpoints must list at least one endpoint when podMonitor.enabled is true" -}}
{{- end -}}
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: {{ include "hwl.fullname" . }}
  labels:
    {{- include "hwl.labels" . | nindent 4 }}
    {{- with $pm.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  selector:
    {{- include "hwl.mainPodSelector" . | nindent 4 }}
  podMetricsEndpoints:
    {{- toYaml $pm.endpoints | nindent 4 }}
{{- end }}
