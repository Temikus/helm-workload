# helm-workload

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Chart Version](https://img.shields.io/github/v/tag/Temikus/helm-workload?label=Chart&sort=semver)](https://github.com/Temikus/helm-workload/releases)

A general-purpose Kubernetes workload Helm chart with batteries included. Deploy any container image as a Deployment or StatefulSet with optional addon sidecars for VPN, PostgreSQL, and Cloudflare Tunnel.

## Prerequisites

- Kubernetes 1.26+
- Helm 3.x

## Installation

### From OCI Registry

```bash
helm install my-release oci://ghcr.io/temikus/helm-charts/workload --version 1.5.1
```

### From Source

```bash
git clone https://github.com/Temikus/helm-workload.git
cd helm-workload
helm install my-release .
```

### With Helmfile (recommended)

```yaml
releases:
  - name: my-app
    namespace: my-namespace
    chart: oci://ghcr.io/temikus/helm-charts/workload
    version: 1.3.3
    values:
      - image:
          repository: nginx
          tag: stable
        ports:
          - name: http
            port: 80
            service:
              enabled: true
              port: 80
```

## Examples

### Simple container

```yaml
image:
  repository: quay.io/curl/curl
  tag: latest
command: ["sleep", "infinity"]
```

### Web application with Ingress and persistence

```yaml
image:
  repository: homebridge/homebridge
  tag: "2024-01-08"

ports:
  - name: http
    port: 8581
    service:
      enabled: true
      port: 8581

persistence:
  enabled: true
  type: statefulset
  storageClassName: longhorn-retained
  mountPath: /homebridge
  accessModes:
    - ReadWriteOnce
  size: 5Gi

ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: traefik
    cert-manager.io/cluster-issuer: letsencrypt-production
  hosts:
    - host: homebridge.example.com
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls:
    - secretName: homebridge-tls
      hosts:
        - homebridge.example.com
```

## Configuration

All configuration is done through `values.yaml`. See the file for full documentation of each field, or use `helm show values oci://ghcr.io/temikus/helm-charts/workload`.

### Key Configuration Areas

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Container image repository | `nginx` |
| `image.tag` | Container image tag | `latest` |
| `replicaCount` | Number of replicas | `1` |
| `ports` | List of container/service port definitions | `[]` |
| `persistence.enabled` | Enable persistent storage | `false` |
| `ingress.enabled` | Enable Ingress resource | `false` |
| `autoscaling.enabled` | Enable HorizontalPodAutoscaler | `false` |
| `hostNetwork.enabled` | Enable host networking | `false` |

### Addons

Addon sidecars are injected into the pod alongside your main container. All addons are disabled by default.

#### Init Container (`addons.init`)

Run an init container before the main application starts.

```yaml
addons:
  init:
    enabled: true
    image:
      repository: busybox
      tag: latest
    command: ["sh", "-c", "echo initializing"]
```

#### VPN (`addons.vpn`)

Adds a [Gluetun](https://github.com/qdm12/gluetun) VPN sidecar. Supports OpenVPN and WireGuard with multiple providers.

```yaml
addons:
  vpn:
    enabled: true
    provider:
      name: mullvad
      type: wireguard
    wireguard:
      privateKey: ""        # or use existingSecret
    config:
      timezone: UTC
      serverSelection:
        countries: Sweden
```

#### PostgreSQL (`addons.postgres`)

Adds a PostgreSQL sidecar with persistent storage. Useful for applications that need a dedicated database.

```yaml
addons:
  postgres:
    enabled: true
    auth:
      username: myapp
      password: secret      # or use existingSecret
      database: myapp_db
    persistence:
      enabled: true
      size: 8Gi
```

#### Cloudflare Tunnel (`addons.cloudflareTunnel`)

Exposes your service through a Cloudflare Tunnel using the [cloudflare-operator](https://github.com/adyanth/cloudflare-operator). Requires the operator to be installed in your cluster.

```yaml
addons:
  cloudflareTunnel:
    enabled: true
    fqdn: myapp.example.com
    protocol: http
    targetPort: 8080
    tunnelRef:
      kind: ClusterTunnel
      name: my-cluster-tunnel
```

Supports optional path filtering (nginx sidecar proxy) and NetworkPolicy for defense-in-depth.

## Known Limitations

- `appVersion` is not dynamically set from the image tag; it mirrors the chart version.

## Development

### Prerequisites

- [Helm](https://helm.sh/) 3.x
- [helm-unittest](https://github.com/helm-unittest/helm-unittest) plugin
- [just](https://github.com/casey/just) (optional, for task automation)

### Commands

```bash
just lint          # Lint the chart
just test          # Run unit tests
just test -u       # Update test snapshots
just build         # Package the chart
```

Or without just:

```bash
helm lint .
helm unittest .
```

## License

Apache License 2.0 - see [LICENSE](LICENSE) for details.
