# helm-workload

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Chart Version](https://img.shields.io/github/v/tag/Temikus/helm-workload?label=Chart&sort=semver)](https://github.com/Temikus/helm-workload/releases)

A general-purpose Kubernetes workload Helm chart with batteries included. Deploy any container image as a Deployment or StatefulSet with optional addon sidecars for VPN, PostgreSQL, and Cloudflare Tunnel.

## Prerequisites

- Kubernetes 1.26+
- Helm 4

## Installation

### From OCI Registry

```bash
helm install my-release oci://ghcr.io/temikus/helm-charts/workload --version 1.8.0
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
    version: 1.8.0
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
| `autoscaling.enabled` | Enable HorizontalPodAutoscaler (`autoscaling/v2`) | `false` |
| `hostNetwork.enabled` | Enable host networking | `false` |
| `strategy` | Rollout strategy (`RollingUpdate`/`Recreate` for Deployment; `RollingUpdate`/`OnDelete` for StatefulSet) | `{}` |
| `networkPolicy.enabled` | Create a NetworkPolicy restricting ingress traffic (and egress, with `networkPolicy.egress`) | `false` |
| `podMonitor.enabled` | Create a Prometheus Operator PodMonitor for the main pods | `false` |
| `runtimeClassName` | Pod RuntimeClass, e.g. `gvisor` | `""` |
| `automountServiceAccountToken` | Set `false` to keep the API token out of the pod; `null` keeps the Kubernetes default | `null` |
| `extraServices` | Additional multi-port Service resources alongside port-derived services | `[]` |
| `env` / `secretEnv` | Environment variables rendered into a ConfigMap / a Secret | `{}` |
| `envFrom` | Extra `secretRef`/`configMapRef` entries for the main container | `[]` |
| `annotations` | Annotations on the Deployment/StatefulSet object (pod template uses `podAnnotations`) | `{}` |
| `addons.infisical.enabled` | Sync an Infisical secrets path into the container env via secrets-operator | `false` |

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

Gluetun shares the pod's network namespace, so its control server (`:8000`) and any HTTP proxy or Shadowsocks server it runs listen on the pod IP. Set `addons.vpn.networkPolicy.enabled: true` to allow ingress only on the pod's declared container ports (`ports`, `extraContainers[].ports`, and the Cloudflare `pathFilter` port), from any source. It is a no-op when `networkPolicy.enabled` or `addons.cloudflareTunnel.networkPolicy.enabled` is set, because those policies already block the gluetun ports and a second policy would only widen them.

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
    runtimeClassName: ""    # not inherited from the top-level runtimeClassName
    networkPolicy:
      enabled: true         # 5432 only from this release's main pods
      from: []              # extra peers, e.g. another release in the namespace
```

The Postgres pod is its own Deployment, so it does not inherit the top-level `runtimeClassName`. `networkPolicy` is off by default because other releases in the same namespace may connect to this database; list them in `from` before enabling it.

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

With `tunnel.create: true`, `tunnel.runtimeClassName` sets the RuntimeClass of the operator's cloudflared pod through the CR's `deployPatch`. A tunnel referenced with `tunnelRef` is managed elsewhere, so its pod can't be changed from here.

#### Infisical (`addons.infisical`)

Syncs a secrets folder from [Infisical](https://infisical.com) into a managed Kubernetes Secret via the [Infisical secrets-operator](https://infisical.com/docs/integrations/platforms/kubernetes/overview) and injects it into the main container's `envFrom`. Requires the operator in your cluster and a universal-auth credentials Secret (`clientId`/`clientSecret`) in the release namespace.

```yaml
addons:
  infisical:
    enabled: true
    hostAPI: https://infisical.example.com/api   # omit for Infisical Cloud
    projectSlug: myproject
    envSlug: prod
    secretsPath: /myapp
    credentialsSecret: infisical-universal-auth  # default
```

Use `keys` to rename secrets on the way in (`ENV_NAME: INFISICAL_KEY`), combined with `includeAllSecrets: false` to expose only those. The workload gets the operator's `secrets.infisical.com/auto-reload` annotation so a rotated secret rolls the pods; set `autoReload: false` to opt out (for example when using [Reloader](https://github.com/stakater/Reloader) via `annotations`).

### Environment Variables (`env`, `secretEnv`, `envFrom`)

```yaml
env:                      # rendered into a ConfigMap
  TZ: UTC
secretEnv:                # rendered into a chart-owned Secret
  API_KEY: "ref+vault://..."
envFrom:                  # appended after the generated refs; later entries win on key clash
  - secretRef:
      name: my-secret
```

### Rollout Strategy (`strategy`)

Configure the rollout strategy for Deployments or StatefulSets. The same `strategy` value is used for both — it maps to `spec.strategy` on Deployments and `spec.updateStrategy` on StatefulSets.

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0
    maxSurge: 1
```

### NetworkPolicy (`networkPolicy`)

Create a Kubernetes NetworkPolicy to restrict ingress traffic to the pod.

```yaml
networkPolicy:
  enabled: true
  # Allow ingress on all ports from .Values.ports (default). Set false for deny-all.
  allowPortsIngress: true
  # Or specify explicit ingress rules:
  ingress:
    - ports:
        - port: 80
          protocol: TCP
      from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
```

`egress` is empty by default, which leaves egress unrestricted. Any rule adds
`Egress` to `policyTypes`, so traffic it doesn't list is denied, DNS included.
For example, DNS plus the public internet only:

```yaml
networkPolicy:
  enabled: true
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - { port: 53, protocol: UDP }
        - { port: 53, protocol: TCP }
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except: [10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 100.64.0.0/10, 169.254.0.0/16]
```

### PodMonitor (`podMonitor`)

Create a Prometheus Operator `PodMonitor` that scrapes the main pods. The
Postgres addon pod is not selected. The cluster needs the
`monitoring.coreos.com` CRDs.

```yaml
podMonitor:
  enabled: true
  # kube-prometheus-stack ignores monitors without its release label.
  labels:
    release: monitoring
  endpoints:
    - port: http
      path: /metrics
      interval: 60s
```

`endpoints` is rendered as `spec.podMetricsEndpoints` unchanged, so any
[PodMetricsEndpoint](https://prometheus-operator.dev/docs/api-reference/api/#monitoring.coreos.com/v1.PodMetricsEndpoint)
field works. `port` is a container port name from `ports`.

### Extra Services (`extraServices`)

Create additional Service resources with custom port mappings (e.g. for UDP discovery protocols or mixed-type services).

```yaml
extraServices:
  - name: device-mgmt
    type: LoadBalancer
    ports:
      - name: discovery
        port: 29810
        targetPort: discovery
        protocol: UDP
      - name: manager
        port: 29811
        targetPort: manager
```

## Known Limitations

- `appVersion` is not dynamically set from the image tag; it mirrors the chart version.

## Development

### Prerequisites

- [Helm](https://helm.sh/) 4
- [helm-unittest](https://github.com/helm-unittest/helm-unittest) plugin
- [kubeconform](https://github.com/yannh/kubeconform) (or `mise install`)
- [just](https://github.com/casey/just) (optional, for task automation)

### Commands

```bash
just lint          # Lint the chart
just test          # Run unit tests and manifest validation
just test unit -u  # Update test snapshots
just test manifests 1.26.15  # Validate ci/*-values.yaml renders against a Kubernetes version
just build         # Package the chart
```

Or without just:

```bash
helm lint .
helm unittest .
```

## License

Apache License 2.0 - see [LICENSE](LICENSE) for details.
