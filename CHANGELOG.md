# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.9.0] - 2026-09-15

### Added
- `envFrom` passthrough for the main container (appended after chart-generated refs)
- `secretEnv`: same shape as `env`, rendered into a chart-owned Secret instead of a ConfigMap
- `annotations`: metadata annotations on the Deployment/StatefulSet object
- `addons.infisical`: renders an `InfisicalSecret` CR (secrets-operator), injects the managed Secret via `envFrom`, and sets `secrets.infisical.com/auto-reload` on the workload

## [1.5.1] - 2025

### Fixed
- CI: add `--verify=false` for helm-unittest plugin install

## [1.5.0] - 2025

### Changed
- Prepared chart for open-source release
- Updated schema defaults to match values.yaml

### Added
- Configurable pod and container security contexts

### Fixed
- Labels no longer applied to StatefulSet `spec.selector` incorrectly

## [1.4.0] - 2025

### Changed
- PostgreSQL addon refactored from sidecar to separate Deployment + Service

## [1.3.3] - 2025

### Fixed
- Security context handling fixes
- Schema defaults aligned with values.yaml

### Added
- Ability to change pod security context
- Force mode for helm push script

## [1.3.1] - 2025

### Security
- Hardened pathFilter nginx sidecar (non-root, read-only root filesystem, no privilege escalation)

## [1.3.0] - 2025

### Fixed
- Fixed tunnelRef.kind mismatch when using existing tunnels vs created tunnels

### Changed
- Replaced broken Cloudflare Tunnel path support with pathFilter nginx sidecar proxy

## [1.2.0] - 2025

### Added
- Cloudflare Tunnel addon with secret management, TunnelBinding, and optional NetworkPolicy

## [1.1.0] - 2025

### Added
- Support for extra containers (`extraContainers`) and extra volumes (`extraVolumes`)

## [1.0.0] - 2024

### Changed
- Inlined all helpers, dropped external `hwl` library chart dependency
- Chart is now fully self-contained

### Added
- Comprehensive unit tests for all templates
- JSON Schema validation (`values.schema.json`)
- Init container addon
- VPN addon (Gluetun-based, OpenVPN/WireGuard)
- PostgreSQL sidecar addon

## [0.x] - 2024

### Added
- Initial release with Deployment/StatefulSet support
- Service, Ingress, HPA, PVC, ServiceAccount templates
- Persistence with multiple volume support
- Host networking option
