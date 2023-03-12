resource "kubectl_manifest" "root_app" {
  depends_on = [helm_release.argocd]

  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: root-app
      namespace: ${var.namespace}
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: default

      source:
        repoURL: https://github.com/adiffpirate/adiffhunting
        targetRevision: ${var.target_revision}
        path: ops/argocd/apps/chart
      destination:
        server: https://kubernetes.default.svc
        namespace: ${var.namespace}

      syncPolicy:
        syncOptions:
          - CreateNamespace=true
        automated:
          selfHeal: true
          prune: true
  YAML
}
