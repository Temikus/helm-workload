# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A general-purpose "batteries-included" Helm chart (`workload`) for deploying containerized applications on Kubernetes. Instead of writing a bespoke chart per app, consumers configure this single chart via values. Published to `oci://ghcr.io/temikus/helm-charts`. Designed to be used with Helmfile.

## Commands

All tasks use [mise](https://mise.jdx.dev/) as the task runner:

```bash
mise run test              # Run unit tests (helm-unittest)
mise run update-snapshot   # Update test snapshots
mise run lint              # Lint the chart
mise run build             # Package chart into pkg/ (runs clean first)
mise run push              # Push to OCI registry (skips if version exists)
mise run clean             # Remove pkg/ and charts/ artifacts
```

Direct equivalents: `helm unittest .`, `helm unittest -u .`, `helm lint .`

To render templates locally for debugging: `helm template <release-name> .`

## Architecture

### Template Organization

Two-tier template system:

- **`templates/*.yaml`** — thin dispatch files that check conditions and include partials
- **`templates/_helpers/*.tpl`** — actual resource definitions, prefixed `hwl.` (helm-workload-library). This was previously an external library chart dependency, inlined in v1.0.0
- **`templates/_helpers.tpl`** — legacy helpers with `workload.*` prefix (duplicates of `hwl.*` helpers from before the refactor)

### Workload Type Selection

The chart auto-selects between Deployment and StatefulSet:
- **StatefulSet** when `useStatefulSet: true` OR `persistence.type` is `sts`/`statefulset`/`StatefulSet`
- **Deployment** otherwise

### Port/Service Model

Ports are a list under `.Values.ports`, each with an optional `.service` sub-config. Multiple Services can be created from a single release. Service naming priority: `nameOverride` > `service.name` > port `name`, appended to fullname.

### Addon System (`.Values.addons`)

| Addon | Purpose |
|---|---|
| `init` | Init container before main app |
| `vpn` | Gluetun VPN sidecar (OpenVPN/WireGuard) |
| `cloudflareTunnel` | Cloudflare Tunnel integration via cloudflare-operator CRDs. Includes pathFilter (nginx sidecar proxy restricting exposed paths) and NetworkPolicy |
| `postgres` | Separate PostgreSQL Deployment + Service (moved from sidecar in v1.4.0). Apps connect via `{fullname}-postgres:5432` |

### Values Schema

`values.schema.json` enforces validation on key fields (image.repository required, enum constraints on pullPolicy, persistence.type, protocols, etc.). Keep this in sync when modifying values structure.

## Testing

Tests use [helm-unittest](https://github.com/helm-unittest/helm-unittest). Test files are in `tests/` with snapshots in `tests/__snapshot__/`.

Tests use assertions: `equal`, `matchRegex`, `exists`/`notExists`, `hasDocuments`, `isKind`, `lengthEqual`, `contains`, `failedTemplate`, and `matchSnapshot`.

When adding new template features:
1. Add test cases in the corresponding `tests/*_test.yaml`
2. Use `mise run update-snapshot` if adding snapshot-based tests
3. Run `mise run test` to verify

## Known Issues

- HPA template uses deprecated `autoscaling/v2beta1` API version
- `appVersion` cannot be set dynamically per-release (always matches chart version)
