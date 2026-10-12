# Clean the pkg and charts directories
clean:
    rm -rf pkg/* charts/*

# Build the chart
build: clean
    helm package -d pkg .

# Push the chart to the repository. Use -f to force overwrite.
push *FLAGS:
    ./scripts/helm_push.sh {{FLAGS}}

# Run all tests, or one suite: just test [unit [-u]|manifests [KUBERNETES_VERSION]]
[positional-arguments]
test *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    case "${1:-}" in
        unit) shift; helm unittest "$@" . ;;
        manifests) shift; {{just_executable()}} _validate-manifests "$@" ;;
        *) helm unittest "$@" . && {{just_executable()}} _validate-manifests ;;
    esac

# Update test snapshots
update-snapshot:
    helm unittest -u .

# Lint the chart
lint:
    helm lint .

# Lint + test
check: lint test

# Release: bump version, commit, tag, and push. Usage: just release [patch|minor|major]
release BUMP:
    #!/usr/bin/env bash
    set -euo pipefail

    # Get current version from Chart.yaml
    CURRENT=$(yq eval '.version' Chart.yaml)
    IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

    case "{{BUMP}}" in
        major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
        minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
        patch) PATCH=$((PATCH + 1)) ;;
        *) echo "Usage: just release [patch|minor|major]"; exit 1 ;;
    esac

    NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
    echo "Bumping version: ${CURRENT} -> ${NEW_VERSION}"

    # Update both version and appVersion in Chart.yaml
    yq eval -i ".version = \"${NEW_VERSION}\"" Chart.yaml
    yq eval -i ".appVersion = \"${NEW_VERSION}\"" Chart.yaml

    # Commit, tag, and push
    git add Chart.yaml
    git commit -m "Release ${NEW_VERSION}"
    git tag -a "v${NEW_VERSION}" -m "Release ${NEW_VERSION}"
    git push origin HEAD
    git push origin "v${NEW_VERSION}"

    echo "Released v${NEW_VERSION}"

# Validate manifests rendered from ci/*-values.yaml against Kubernetes schemas.
# CRD schemas are vendored in ci/schemas: cloudflare-operator v0.13.1 (converted
# with kubeconform's openapi2jsonschema.py) and Infisical from datreeio/CRDs-catalog.
_validate-manifests KUBERNETES_VERSION="1.37.1":
    #!/usr/bin/env bash
    set -euo pipefail
    for f in ci/*-values.yaml; do
        echo "==> $f"
        helm template ci . -f "$f" | kubeconform -strict -summary \
            -kubernetes-version "{{KUBERNETES_VERSION}}" \
            -schema-location default \
            -schema-location 'ci/schemas/{{{{.ResourceKind}}_{{{{.ResourceAPIVersion}}.json'
    done
