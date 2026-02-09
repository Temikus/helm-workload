{{/*
Gluetun VPN sidecar container configuration
*/}}
{{- define "hwl.gluetun.sidecar" -}}
{{- $vpn := .Values.addons.vpn -}}
{{- if $vpn.enabled -}}
- name: gluetun
  {{- with $vpn.image }}
  image: {{ .repository | default "ghcr.io/qdm12/gluetun" }}:{{ .tag | default "latest" }}
  imagePullPolicy: {{ .pullPolicy | default "Always" }}
  {{- end }}
  securityContext:
    privileged: true {{/* Required for TUN device management */}}
    capabilities:
      add:
        - NET_ADMIN
        - NET_RAW
  env:
    {{- if dig "firewall" "outboundSubnets" nil $vpn }}
    - name: FIREWALL_OUTBOUND_SUBNETS
      value: {{ join "," $vpn.firewall.outboundSubnets | quote }}
    {{- end }}
    - name: TZ
      value: {{ default "UTC" (dig "config" "timezone" "UTC" $vpn) | quote }}
    - name: VPN_SERVICE_PROVIDER
      value: {{ required "VPN provider name is required" $vpn.provider.name | quote }}
    - name: VPN_TYPE
      value: {{ required "VPN connection type is required" $vpn.provider.type | quote }}
    - name: DOT
      value: "off"
    - name: DNS_NAMESERVERS
      value: "1.1.1.1,1.0.0.1"  # Cloudflare
    {{- if eq $vpn.provider.type "openvpn" }}
    {{- if dig "openvpn" "auth" "existingSecret" nil $vpn }}
    - name: OPENVPN_USER
      valueFrom:
        secretKeyRef:
          name: {{ $vpn.openvpn.auth.existingSecret }}
          key: {{ dig "openvpn" "auth" "existingSecretUsernameKey" "username" $vpn }}
    - name: OPENVPN_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ $vpn.openvpn.auth.existingSecret }}
          key: {{ dig "openvpn" "auth" "existingSecretPasswordKey" "password" $vpn }}
    {{- else }}
    - name: OPENVPN_USER
      value: {{ required "OpenVPN username is required" (dig "openvpn" "auth" "username" "" $vpn) | quote }}
    - name: OPENVPN_PASSWORD
      value: {{ required "OpenVPN password is required" (dig "openvpn" "auth" "password" "" $vpn) | quote }}
    {{- end }}
    {{- end }}
    {{- if eq $vpn.provider.type "wireguard" }}
    {{- if dig "wireguard" "existingSecret" nil $vpn }}
    - name: WIREGUARD_PRIVATE_KEY
      valueFrom:
        secretKeyRef:
          name: {{ $vpn.wireguard.existingSecret }}
          key: privateKey
    {{- else }}
    - name: WIREGUARD_PRIVATE_KEY
      value: {{ required "WireGuard private key is required" (dig "wireguard" "privateKey" "" $vpn) | quote }}
    {{- end }}
    {{- if dig "wireguard" "addresses" nil $vpn }}
    - name: WIREGUARD_ADDRESSES
      value: {{ join "," $vpn.wireguard.addresses | quote }}
    {{- end }}
    {{- end }}
    {{- with dig "config" "serverSelection" dict $vpn }}
    {{- if .countries }}
    - name: SERVER_COUNTRIES
      value: {{ join "," .countries | quote }}
    {{- end }}
    {{- if .cities }}
    - name: SERVER_CITIES
      value: {{ join "," .cities | quote }}
    {{- end }}
    {{- if .hostnames }}
    - name: SERVER_HOSTNAMES
      value: {{ join "," .hostnames | quote }}
    {{- end }}
    {{- end }}
    {{- if dig "config" "portForward" "enabled" false $vpn }}
    - name: VPN_PORT_FORWARDING
      value: "on"
    {{- end }}
    {{- range $env := $vpn.additionalEnv }}
    - name: {{ $env.name }}
      value: {{ $env.value }}
    {{- end }}

  {{- include "hwl.gluetun.volumeMounts" . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Gluetun volume mounts
*/}}
{{- define "hwl.gluetun.volumeMounts" -}}
{{- $vpn := .Values.addons.vpn -}}
{{- if $vpn.enabled }}
volumeMounts:
  - name: gluetun-config
    mountPath: /gluetun
{{- end }}
{{- end }}

{{/*
Gluetun volumes
*/}}
{{- define "hwl.gluetun.volumes" -}}
{{- $vpn := .Values.addons.vpn -}}
{{- if $vpn.enabled }}
- name: gluetun-config
  {{- if dig "persistence" "existingClaim" nil $vpn }}
  persistentVolumeClaim:
    claimName: {{ $vpn.persistence.existingClaim }}
  {{- else if dig "persistence" "enabled" false $vpn }}
  persistentVolumeClaim:
    claimName: {{ include "hwl.fullname" . }}-gluetun
  {{- else }}
  emptyDir: {}
  {{- end }}
{{- end }}
{{- end }}