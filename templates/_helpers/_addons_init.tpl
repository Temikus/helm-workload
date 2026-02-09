{{/*
Init container template
*/}}
{{- define "hwl.init.container" -}}
{{- $init := .Values.addons.init -}}
{{- if $init.enabled }}
- name: init
  image: "{{ $init.image.repository }}:{{ $init.image.tag }}"
  imagePullPolicy: {{ $init.image.pullPolicy }}
  {{- with $init.command }}
  command:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $init.securityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $init.volumeMounts }}
  volumeMounts:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}