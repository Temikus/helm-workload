# CLAUDE.md — workload chart

General-purpose Kubernetes workload Helm chart with addon sidecars (VPN, Postgres, Cloudflare Tunnel).

## Commands

Run from this directory (`charts/workload`):

- `just lint` — helm lint
- `just test` — helm unittest
- `just test -u` — update snapshots
- `helm unittest -f tests/<test_name>.yaml .` — run single test file

## Architecture

### Template structure

Each Kubernetes resource has a top-level template file (`templates/*.yaml`) that includes helpers from `templates/_helpers/_*.tpl`. The top-level files contain conditional rendering logic and `---` document separators; the helpers contain the actual resource definitions via `define`/`include`.

- `_common.tpl` — fullname, labels, selectorLabels, serviceAccountName
- `_pod.tpl` — pod template spec (containers, volumes, sidecars)
- `_container.tpl` — main application container
- `_deployment.tpl` / `_statefulset.tpl` — workload controllers
- `_addons_*.tpl` — addon sidecar definitions

### Addon sidecar pattern

Addons follow a consistent pattern:

1. **Helper file** (`_helpers/_addons_<name>.tpl`) defines named templates for sidecar container, volumes, and any extra resources (Secrets, ConfigMaps, Services)
2. **Pod injection** (`_pod.tpl`) conditionally includes the sidecar in `containers:` and volumes in `volumes:` using `((.Values.addons.<name>).enabled)` safe-navigation
3. **Resource rendering** — addon-specific resources get their own top-level template file (e.g. `cloudflare_tunnel.yaml`) or are included from the deployment/statefulset templates
4. **Values** live under `addons.<name>` with `enabled: false` default
5. **Schema** validated in `values.schema.json`

### Pod template injection points (`_pod.tpl`)

Sidecars are injected **before** `extraContainers` and the main container. Volumes are injected **after** host volumes and before `extraVolumes`. The volumes `if` condition must include all addons that contribute volumes.

### Cloudflare Tunnel addon

Resources (in template rendering order, document indices follow this order in helm-unittest):

1. Secret (when `tunnel.create` + inline credentials)
2. Tunnel/ClusterTunnel (when `tunnel.create`)
3. TunnelBinding (always when enabled)
4. NetworkPolicy (when `networkPolicy.enabled`)
5. pathFilter ConfigMap (when `pathFilter.enabled`)
6. pathFilter Service (when `pathFilter.enabled`)

**Note:** `helm template` sorts output by resource kind, but `helm unittest` preserves template rendering order. Always use rendering order for `documentIndex` in tests.

#### tunnelRef.kind derivation

- `tunnel.create=true` — tunnelRef.kind comes from `tunnel.kind`
- `tunnel.create=false` — tunnelRef.kind comes from `tunnelRef.kind`

Both default to `ClusterTunnel`.

#### pathFilter design

Traffic flow: `Cloudflare Tunnel -> cf-path-filter Service (ClusterIP) -> nginx sidecar -> 127.0.0.1:targetPort`

- Nginx sidecar runs as non-root (uid 101), read-only root filesystem, no privilege escalation
- Uses `livenessProbe` (not readinessProbe) so sidecar failure doesn't pull the pod from the main Service endpoints — the app also serves local traffic via Ingress
- Needs writable emptyDir volumes for `/var/cache/nginx`, `/var/run`, `/var/log/nginx`
- Nginx must listen on `0.0.0.0` (not localhost) because the Service routes via podIP
- The `paths` value is required when `pathFilter.enabled=true` (enforced via `fail`)
- Cloudflare rejects paths in TunnelBinding `target` field — that's why this sidecar proxy exists instead of appending paths to the target URL

#### Known security considerations

- `pathFilter.paths` values are interpolated directly into nginx config — no sanitization (schema should constrain with a pattern)
- The cf-path-filter Service is reachable by any pod in the cluster; use `networkPolicy` for isolation
- When both `networkPolicy` and `pathFilter` are enabled, the NetworkPolicy allows the pathFilter port in addition to the targetPort

## Testing conventions

- Test file names match template names: `tests/addons_cloudflare_tunnel_test.yaml` tests `cloudflare_tunnel.yaml`
- The `templates:` list at top of test file must include all templates referenced by tests (e.g. both `cloudflare_tunnel.yaml` and `deployment.yaml` for pod-level tests)
- Use `documentIndex` based on **rendering order**, not kind-alphabetical order
- Use `failedTemplate` assertion to test `fail` guards
- Snapshot tests exist for deployment, ingress, and service — run `just test -u` after version bumps

## Files to update together

When modifying an addon:
- `templates/_helpers/_addons_<name>.tpl` — resource definitions
- `templates/_helpers/_pod.tpl` — sidecar + volume injection (and the volumes `if` condition)
- `templates/<name>.yaml` — top-level rendering with document separators
- `values.yaml` — default values
- `values.schema.json` — JSON schema validation
- `tests/addons_<name>_test.yaml` — unit tests
