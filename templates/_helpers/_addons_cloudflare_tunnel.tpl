{{/*
Cloudflare credentials Secret
Creates a Kubernetes Secret containing Cloudflare API credentials.
Only rendered when tunnel.create is true and no existingSecret is specified.
Supports apiToken (recommended) and/or apiKey.
*/}}
{{- define "hwl.cloudflareTunnel.secret" -}}
{{- $cf := .Values.addons.cloudflareTunnel -}}
{{- $creds := $cf.tunnel.cloudflare.credentials -}}
{{- if and $cf.enabled $cf.tunnel.create (not $creds.existingSecret) -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "hwl.fullname" . }}-cf-credentials
  labels:
    {{- include "hwl.labels" . | nindent 4 }}
type: Opaque
stringData:
  {{- if $creds.apiToken }}
  CLOUDFLARE_API_TOKEN: {{ $creds.apiToken | quote }}
  {{- end }}
  {{- if $creds.apiKey }}
  CLOUDFLARE_API_KEY: {{ $creds.apiKey | quote }}
  {{- end }}
  {{- if not (or $creds.apiToken $creds.apiKey) }}
  {{- fail "addons.cloudflareTunnel.tunnel.cloudflare.credentials: either apiToken, apiKey, or existingSecret is required when tunnel.create is true" }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Helper: resolve the Secret name for cloudflare credentials.
Returns existingSecret if set, otherwise the auto-generated secret name.
*/}}
{{- define "hwl.cloudflareTunnel.secretName" -}}
{{- $creds := .Values.addons.cloudflareTunnel.tunnel.cloudflare.credentials -}}
{{- if $creds.existingSecret -}}
  {{- $creds.existingSecret -}}
{{- else -}}
  {{- printf "%s-cf-credentials" (include "hwl.fullname" .) -}}
{{- end -}}
{{- end }}

{{/*
Cloudflare Tunnel resource (Tunnel or ClusterTunnel)
Creates a new tunnel via the cloudflare-operator CRD.
Only rendered when addons.cloudflareTunnel.tunnel.create is true.
*/}}
{{- define "hwl.cloudflareTunnel.tunnel" -}}
{{- $cf := .Values.addons.cloudflareTunnel -}}
{{- if and $cf.enabled $cf.tunnel.create -}}
apiVersion: networking.cfargotunnel.com/v1alpha2
kind: {{ $cf.tunnel.kind | default "ClusterTunnel" }}
metadata:
  name: {{ include "hwl.fullname" . }}-tunnel
  labels:
    {{- include "hwl.labels" . | nindent 4 }}
spec:
  cloudflare:
    accountId: {{ required "addons.cloudflareTunnel.tunnel.cloudflare.accountId is required when tunnel.create is true" $cf.tunnel.cloudflare.accountId | quote }}
    domain: {{ required "addons.cloudflareTunnel.tunnel.cloudflare.domain is required when tunnel.create is true" $cf.tunnel.cloudflare.domain | quote }}
    email: {{ required "addons.cloudflareTunnel.tunnel.cloudflare.email is required when tunnel.create is true" $cf.tunnel.cloudflare.email | quote }}
    secret: {{ include "hwl.cloudflareTunnel.secretName" . }}
  newTunnel:
    name: {{ $cf.tunnel.name | default (printf "%s-tunnel" (include "hwl.fullname" .)) }}
  fallbackTarget: {{ $cf.tunnel.fallbackTarget | default "http_status:404" }}
  noTlsVerify: {{ $cf.tunnel.noTlsVerify | default false }}
{{- end }}
{{- end }}

{{/*
Cloudflare TunnelBinding resource
Binds a Service to a Tunnel/ClusterTunnel.

SECURITY: The target field is always explicitly set to the full
protocol://service.namespace.svc.cluster.local:port/path URL. This ensures
the tunnel can ONLY reach the designated service, port, and path -- no other
services, ports, or paths in the cluster are reachable through this binding.
*/}}
{{- define "hwl.cloudflareTunnel.tunnelBinding" -}}
{{- $cf := .Values.addons.cloudflareTunnel -}}
{{- if $cf.enabled -}}
{{- $serviceName := ($cf.serviceName | default (include "hwl.fullname" .)) -}}
{{- $protocol := ($cf.protocol | default "http") -}}
{{- $targetPort := (required "addons.cloudflareTunnel.targetPort is required" $cf.targetPort) -}}
{{- $path := ($cf.path | default "") -}}
{{- $tunnelRefName := "" -}}
{{- if $cf.tunnel.create -}}
  {{- $tunnelRefName = (printf "%s-tunnel" (include "hwl.fullname" .)) -}}
{{- else -}}
  {{- $tunnelRefName = (required "addons.cloudflareTunnel.tunnelRef.name is required when tunnel.create is false" $cf.tunnelRef.name) -}}
{{- end -}}
apiVersion: networking.cfargotunnel.com/v1alpha1
kind: TunnelBinding
metadata:
  name: {{ include "hwl.fullname" . }}
  labels:
    {{- include "hwl.labels" . | nindent 4 }}
subjects:
  - kind: Service
    name: {{ $serviceName }}
    spec:
      fqdn: {{ required "addons.cloudflareTunnel.fqdn is required" $cf.fqdn }}
      protocol: {{ $protocol }}
      target: "{{ $protocol }}://{{ $serviceName }}.{{ .Release.Namespace }}.svc.cluster.local:{{ $targetPort }}{{ $path }}"
      {{- if $cf.caPool }}
      caPool: {{ $cf.caPool }}
      {{- end }}
      {{- if $cf.noTlsVerify }}
      noTlsVerify: {{ $cf.noTlsVerify }}
      {{- end }}
tunnelRef:
  kind: {{ $cf.tunnelRef.kind | default "ClusterTunnel" }}
  name: {{ $tunnelRefName }}
  disableDNSUpdates: {{ $cf.tunnelRef.disableDNSUpdates | default false }}
{{- end }}
{{- end }}

{{/*
Cloudflare Tunnel NetworkPolicy
Restricts pod ingress to only the tunnel-bound port.
This provides defense-in-depth: even if the TunnelBinding target is
somehow misconfigured, the NetworkPolicy ensures only the intended
port accepts inbound traffic.
*/}}
{{- define "hwl.cloudflareTunnel.networkPolicy" -}}
{{- $cf := .Values.addons.cloudflareTunnel -}}
{{- if and $cf.enabled $cf.networkPolicy.enabled -}}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "hwl.fullname" . }}-cf-tunnel
  labels:
    {{- include "hwl.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "hwl.selectorLabels" . | nindent 6 }}
  policyTypes:
    - Ingress
  ingress:
    - ports:
        - protocol: TCP
          port: {{ $cf.targetPort }}
{{- end }}
{{- end }}
