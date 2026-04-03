# Clean the pkg and charts directories
clean:
    rm -rf pkg/* charts/*

# Build the chart
build: clean
    helm package -d pkg .

# Push the chart to the repository. Use -f to force overwrite.
push *FLAGS:
    ./scripts/helm_push.sh {{FLAGS}}

# Run unit tests. Pass -u to update snapshots.
test *ARGS:
    helm unittest {{ARGS}} .

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
