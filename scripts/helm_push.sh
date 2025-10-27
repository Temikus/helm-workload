#!/usr/bin/env bash
set -e

# Extract chart name and version from Chart.yaml
CHART_NAME=$(yq eval '.name' Chart.yaml)
CHART_VERSION=$(yq eval '.version' Chart.yaml)
OCI_REGISTRY="oci://ghcr.io/temikus/helm-charts"

echo "Chart: $CHART_NAME"
echo "Version: $CHART_VERSION"
echo "Registry: $OCI_REGISTRY"

# Check if the version already exists in the remote registry
echo "Checking if version $CHART_VERSION already exists in remote registry..."
if helm pull "${OCI_REGISTRY}/${CHART_NAME}" --version "${CHART_VERSION}" --destination /tmp --untar=false 2>/dev/null; then
    echo "❌ Version $CHART_VERSION already exists in the remote registry. Skipping push to prevent overwriting."
    rm -f "/tmp/${CHART_NAME}-${CHART_VERSION}.tgz"
    exit 0
else
    echo "✅ Version $CHART_VERSION does not exist in the remote registry. Proceeding with push..."
    helm push pkg/*.tgz "${OCI_REGISTRY}"
    echo "✅ Successfully pushed $CHART_NAME:$CHART_VERSION"
fi
