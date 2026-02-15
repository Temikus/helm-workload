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
protocol://service.namespace.svc.cluster.local:port URL. This ensures
the tunnel can ONLY reach the designated service and port -- no other
services or ports in the cluster are reachable through this binding.
When pathFilter is enabled, traffic is routed through the path-filter
proxy Service which only allows configured paths.
*/}}
{{- define "hwl.cloudflareTunnel.tunnelBinding" -}}
{{- $cf := .Values.addons.cloudflareTunnel -}}
{{- if $cf.enabled -}}
{{- $serviceName := ($cf.serviceName | default (include "hwl.fullname" .)) -}}
{{- $protocol := ($cf.protocol | default "http") -}}
{{- $targetPort := (required "addons.cloudflareTunnel.targetPort is required" $cf.targetPort) -}}
{{- $tunnelRefName := "" -}}
{{- $tunnelRefKind := "" -}}
{{- if $cf.tunnel.create -}}
  {{- $tunnelRefName = (printf "%s-tunnel" (include "hwl.fullname" .)) -}}
  {{- $tunnelRefKind = ($cf.tunnel.kind | default "ClusterTunnel") -}}
{{- else -}}
  {{- $tunnelRefName = (required "addons.cloudflareTunnel.tunnelRef.name is required when tunnel.create is false" $cf.tunnelRef.name) -}}
  {{- $tunnelRefKind = ($cf.tunnelRef.kind | default "ClusterTunnel") -}}
{{- end -}}
{{- $pf := ($cf.pathFilter | default dict) -}}
{{- $pfEnabled := ($pf.enabled | default false) -}}
{{- $targetServiceName := $serviceName -}}
{{- $targetServicePort := $targetPort -}}
{{- if $pfEnabled -}}
  {{- $targetServiceName = (printf "%s-cf-path-filter" (include "hwl.fullname" .)) -}}
  {{- $targetServicePort = ($pf.port | default 8880) -}}
{{- end -}}
apiVersion: networking.cfargotunnel.com/v1alpha1
kind: TunnelBinding
metadata:
  name: {{ include "hwl.fullname" . }}
  labels:
    {{- include "hwl.labels" . | nindent 4 }}
subjects:
  - kind: Service
    name: {{ $targetServiceName }}
    spec:
      fqdn: {{ required "addons.cloudflareTunnel.fqdn is required" $cf.fqdn }}
      protocol: {{ $protocol }}
      target: "{{ $protocol }}://{{ $targetServiceName }}.{{ .Release.Namespace }}.svc.cluster.local:{{ $targetServicePort }}"
      {{- if $cf.caPool }}
      caPool: {{ $cf.caPool }}
      {{- end }}
      {{- if $cf.noTlsVerify }}
      noTlsVerify: {{ $cf.noTlsVerify }}
      {{- end }}
tunnelRef:
  kind: {{ $tunnelRefKind }}
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

{{/*
Cloudflare Tunnel path-filter ConfigMap
Creates an nginx configuration that only allows traffic to specified paths,
returning 403 for everything else.

NOTE: nginx must listen on 0.0.0.0 (not 127.0.0.1) because the
cf-path-filter Service routes traffic to the pod via its podIP.
Restrict cluster-level access to this proxy using networkPolicy if needed.
*/}}
{{- define "hwl.cloudflareTunnel.pathFilter.configMap" -}}
{{- $cf := .Values.addons.cloudflareTunnel -}}
{{- $pf := $cf.pathFilter -}}
{{- if not $pf.paths -}}
  {{- fail "addons.cloudflareTunnel.pathFilter.paths is required when pathFilter.enabled is true" -}}
{{- end -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "hwl.fullname" . }}-cf-path-filter
  labels:
    {{- include "hwl.labels" . | nindent 4 }}
data:
  nginx.conf: |
    log_format security '[$time_local] $remote_addr - $http_x_real_ip - $http_x_forwarded_for - "$request_method $uri" $status';
    server {
        listen {{ $pf.port | default 8880 }};
        server_tokens off;
        access_log /dev/stdout security;
        {{- range $pf.paths }}
        location {{ . }} {
            proxy_pass http://127.0.0.1:{{ $cf.targetPort }};
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        {{- end }}
        location / {
            return 403;
        }
    }
{{- end }}

{{/*
Cloudflare Tunnel path-filter sidecar container
Runs nginx to filter requests by path before forwarding to the main container.
Hardened: non-root, read-only root filesystem, no privilege escalation.
*/}}
{{- define "hwl.cloudflareTunnel.pathFilter.sidecar" -}}
{{- $cf := .Values.addons.cloudflareTunnel -}}
{{- $pf := $cf.pathFilter -}}
{{- $image := ($pf.image | default dict) -}}
- name: cf-path-filter
  image: "{{ $image.repository | default "nginx" }}:{{ $image.tag | default "alpine" }}"
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
    runAsGroup: 101
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
  ports:
    - containerPort: {{ $pf.port | default 8880 }}
      protocol: TCP
  livenessProbe:
    tcpSocket:
      port: {{ $pf.port | default 8880 }}
    initialDelaySeconds: 2
    periodSeconds: 10
  volumeMounts:
    - name: cf-path-filter-config
      mountPath: /etc/nginx/conf.d
      readOnly: true
    - name: cf-path-filter-cache
      mountPath: /var/cache/nginx
    - name: cf-path-filter-run
      mountPath: /var/run
    - name: cf-path-filter-log
      mountPath: /var/log/nginx
{{- end }}

{{/*
Cloudflare Tunnel path-filter volumes
ConfigMap for nginx config plus writable dirs needed with readOnlyRootFilesystem.
*/}}
{{- define "hwl.cloudflareTunnel.pathFilter.volumes" -}}
- name: cf-path-filter-config
  configMap:
    name: {{ include "hwl.fullname" . }}-cf-path-filter
- name: cf-path-filter-cache
  emptyDir: {}
- name: cf-path-filter-run
  emptyDir: {}
- name: cf-path-filter-log
  emptyDir: {}
{{- end }}

{{/*
Cloudflare Tunnel path-filter Service
Creates a dedicated Service for the path-filter proxy, selecting the same pods
as the main workload. This avoids modifying the main Service template.
*/}}
{{- define "hwl.cloudflareTunnel.pathFilter.service" -}}
{{- $cf := .Values.addons.cloudflareTunnel -}}
{{- $pf := $cf.pathFilter -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "hwl.fullname" . }}-cf-path-filter
  labels:
    {{- include "hwl.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  selector:
    {{- include "hwl.selectorLabels" . | nindent 4 }}
  ports:
    - port: {{ $pf.port | default 8880 }}
      targetPort: {{ $pf.port | default 8880 }}
      protocol: TCP
      name: cf-path-filter
{{- end }}
