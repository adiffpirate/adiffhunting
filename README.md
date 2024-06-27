# A Different Hunting

My pet project designed to mass scan Bug Bounty targets using Cloud/DevOps/SRE best practices.

This repository is public so curious people can understand my hacking methodology and
to showcase my knowledge in Cloud DevOps Engineering for job interviews :stuck_out_tongue_winking_eye:

**It is intended for personal use, so there is no extensive documentation provided.**

> This project is licensed under the MIT license, so feel free to fork and customize it as you wish.

## How to Run

1. Save your [SOPS](https://github.com/getsops/sops) Age Private Key into `~/.config/sops/age/keys.txt`.

> SOPS is used to securely expose this repository. All sensitive information is encrypted.

2. Connect to a Kubernetes Cluster.

3. Run the following commands to install everything:

```sh
export ADH_APPS_NAMESPACE='adh' && export ADH_OBSERVABILITY_NAMESPACE='observability' \
&& git pull \
&& helm repo add dgraph https://charts.dgraph.io \
&& helm repo add prometheus-community https://prometheus-community.github.io/helm-charts \
&& helm repo add grafana https://grafana.github.io/helm-charts \
&& helm repo update \
&& helm upgrade --install dgraph dgraph/dgraph --namespace $ADH_APPS_NAMESPACE --create-namespace --values ops/live/adh-db/dgraph/values.yaml \
&& helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack --namespace $ADH_OBSERVABILITY_NAMESPACE --create-namespace --values ops/live/observability/prometheus-stack/values.yaml \
&& helm upgrade --install promtail grafana/promtail --namespace $ADH_OBSERVABILITY_NAMESPACE --create-namespace --values ops/live/observability/promtail/values.yaml \
&& helm upgrade --install loki grafana/loki --namespace $ADH_OBSERVABILITY_NAMESPACE --create-namespace --values ops/live/observability/loki/values.yaml \
&& find ops/live -name '*.yaml' | xargs -I{} sh -c 'if grep -q apiVersion: {} && grep -q kind: {} && grep -q metadata: {} ; then echo --- ; sops -d {} 2>/dev/null || cat {}; fi' | kubectl apply -n $ADH_APPS_NAMESPACE --force -f -
```

> Previously, I had ArgoCD installed for GitOps, but I found it unnecessary due to the low frequency
> of changes/deployments and the lack of team collaboration (as I am the sole manager of this environment).
>
> I may reintegrate it in the future if the project scales to the point where multiple Kubernetes clusters are needed.
>
> The old ArgoCD code can be found here: https://github.com/adiffpirate/adiffhunting/commit/0df6678679f0678b12b18271c5b4e333b2339124
