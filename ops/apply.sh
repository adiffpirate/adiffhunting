#!/bin/bash

GIT_ROOT_DIR="$(git rev-parse --show-toplevel)"

ADH_APPS_NAMESPACE='adh'
ADH_OBSERVABILITY_NAMESPACE='observability'

git pull

if [[ "$1" == "all" ]]; then
	helm repo add dgraph https://charts.dgraph.io
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update

	helm upgrade --install dgraph dgraph/dgraph \
		--namespace $ADH_APPS_NAMESPACE --create-namespace \
		--values $GIT_ROOT_DIR/ops/live/adh-db/dgraph/values.yaml
	helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
		--namespace $ADH_OBSERVABILITY_NAMESPACE --create-namespace \
		--values $GIT_ROOT_DIR/ops/live/observability/prometheus-stack/values.yaml
	helm upgrade --install promtail grafana/promtail \
		--namespace $ADH_OBSERVABILITY_NAMESPACE --create-namespace \
		--values $GIT_ROOT_DIR/ops/live/observability/promtail/values.yaml
	helm upgrade --install loki grafana/loki \
		--namespace $ADH_OBSERVABILITY_NAMESPACE --create-namespace \
		--values $GIT_ROOT_DIR/ops/live/observability/loki/values.yaml
fi

# Apply k8s decrypted manifests
find $GIT_ROOT_DIR/ops/live -name '*.yaml' | while read -r file; do
  # Check if the file contains the necessary fields (apiVersion, kind, metadata)
  if grep -q apiVersion: "$file" && grep -q kind: "$file" && grep -q metadata: "$file"; then
    echo "---"
    # Attempt to decrypt the file with `sops`. If decryption fails, output the raw file content
    sops -d "$file" 2>/dev/null || cat "$file"
  fi
done | kubectl apply -n "$ADH_APPS_NAMESPACE" --force -f -
