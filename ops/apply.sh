#!/bin/bash

usage() {
  echo "Usage: $0 -s [full|apps] -p [prod|dev]"
  exit 1
}

# Parse flags
while getopts "s:p:" opt; do
  case "$opt" in
    s) SCOPE="$OPTARG" ;;
    p) PROFILE="$OPTARG" ;;
    *) usage ;;
  esac
done

if [[ -z "$SCOPE" || -z "$PROFILE" ]]; then
  usage
fi

GIT_ROOT_DIR="$(git rev-parse --show-toplevel)"
GIT_HASH=$(git rev-parse --short HEAD)
EPOCH_TIMESTAMP=$(date +%s)

ADH_APPS_NAMESPACE='adh'
ADH_OBSERVABILITY_NAMESPACE='observability'

git pull

if [[ "$PROFILE" == "dev" ]]; then
  if kind get clusters 2>&1 | grep -q 'No kind clusters found'; then
    $GIT_ROOT_DIR/ops/create_dev_cluster.sh
  fi
fi

# Run helm commands only if scope is set to "full"
if [[ "$SCOPE" == "full" ]]; then
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo add grafana https://grafana.github.io/helm-charts
	helm repo add cnpg https://cloudnative-pg.github.io/charts
  helm repo update

  helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace $ADH_OBSERVABILITY_NAMESPACE --create-namespace \
    --values $GIT_ROOT_DIR/ops/live/observability/prometheus-stack/values.yaml \
    --version '69.8.2'
  helm upgrade --install promtail grafana/promtail \
    --namespace $ADH_OBSERVABILITY_NAMESPACE --create-namespace \
    --values $GIT_ROOT_DIR/ops/live/observability/promtail/values.yaml \
    --version '6.16.6'
  helm upgrade --install loki grafana/loki \
    --namespace $ADH_OBSERVABILITY_NAMESPACE --create-namespace \
    --values $GIT_ROOT_DIR/ops/live/observability/loki/values.yaml \
    --version '6.28.0'
	helm upgrade --install cnpg cnpg/cloudnative-pg \
		--namespace $ADH_APPS_NAMESPACE --create-namespace \
    --values $GIT_ROOT_DIR/ops/live/adh-db/cloudnative-pg/values.yaml \
    --version '0.23.2'
fi

DEV_LOCAL_REGISTRY='localhost:5001'
DEV_IMAGE_TAG="${GIT_HASH}-dev-${EPOCH_TIMESTAMP}"

# If profile is "dev", build and push local Docker images
if [[ "$PROFILE" == "dev" ]]; then
  find "$GIT_ROOT_DIR" -name 'Dockerfile' -type f | while read -r dockerfile; do
    # Extract app name from the two parent folders
    app_name=$(echo "$dockerfile" | awk -F'/' '{print $(NF-2) "-" $(NF-1)}')

    # Generate image tag
    image_name="${DEV_LOCAL_REGISTRY}/adiffhunting/${app_name}:${DEV_IMAGE_TAG}"

    echo "Building image: $image_name"
    docker build -t "$image_name" -f "$dockerfile" $GIT_ROOT_DIR/dev
    docker push "$image_name"
  done
fi

# Apply k8s decrypted manifests
find "$GIT_ROOT_DIR/ops/live" -name '*.yaml' | while read -r file; do
  # Check if the file contains the necessary fields (apiVersion, kind, metadata)
  if grep -q apiVersion: "$file" && grep -q kind: "$file" && grep -q metadata: "$file"; then
    echo "---"
    # Attempt to decrypt the file with `sops`. If decryption fails, output the raw file content
    sops -d "$file" 2>/dev/null || cat "$file"
  fi
done | {
  # If the profile is "dev", modify the image lines to pull from localhost:5001
  if [[ "$PROFILE" == "dev" ]]; then
    sed -E "s/(image:[[:space:]]*)(.*):(.*)/\\1${DEV_LOCAL_REGISTRY}\\/\\2:${DEV_IMAGE_TAG}/"
  else
    cat
  fi
} | kubectl apply -n "$ADH_APPS_NAMESPACE" --force -f -
