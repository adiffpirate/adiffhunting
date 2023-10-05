locals {
  argocd_values = <<-YAML
    configs:
      repositories:
        adiffhunting:
          url: https://github.com/adiffpirate/adiffhunting
          name: repo-adiffhunting
          type: git
          username: ${var.github_username}
          password: ${var.github_token}

    repoServer:
      env:
        - name: HELM_PLUGINS
          value: /custom-tools/helm-plugins/
        - name: HELM_SECRETS_SOPS_PATH
          value: /custom-tools/sops
        - name: HELM_SECRETS_CURL_PATH
          value: /custom-tools/curl
        - name: HELM_SECRETS_BACKEND
          value: sops
        - name: SOPS_AGE_KEY_FILE
          value: /sops/private.key
      volumes:
        - name: custom-tools
          emptyDir: {}
        - name: sops-private-key
          secret:
            secretName: sops-private-key
        - name: plugin-plain-and-encrypted-yaml-files
          configMap:
            name: plugin-plain-and-encrypted-yaml-files
      volumeMounts:
        - mountPath: /custom-tools
          name: custom-tools
        - mountPath: /usr/local/sbin/helm
          subPath: helm
          name: custom-tools
        - mountPath: /sops
          name: sops-private-key

      # Install tools needed by Helm Secrets to decrypt values files
      initContainers:
        - name: download-tools
          image: alpine:latest
          command: [sh, -ec]
          env:
            - name: HELM_SECRETS_VERSION
              value: "4.3.0"
            - name: SOPS_VERSION
              value: "3.7.3"
          args:
            - |
              mkdir -p /custom-tools/helm-plugins
              wget -qO- https://github.com/jkroepke/helm-secrets/releases/download/v$${HELM_SECRETS_VERSION}/helm-secrets.tar.gz | tar -C /custom-tools/helm-plugins -xzf-;
              wget -qO /custom-tools/sops https://github.com/mozilla/sops/releases/download/v$${SOPS_VERSION}/sops-v$${SOPS_VERSION}.linux
              printf '#!/usr/bin/env sh\nexec /usr/local/bin/helm secrets "$@"' > /custom-tools/helm
              chmod +x /custom-tools/*
          volumeMounts:
            - mountPath: /custom-tools
              name: custom-tools

      # Sidecar with sops plugin to decrypt k8s manifests files
      extraContainers:
        - name: plugin-plain-and-encrypted-yaml-files
          command: [/var/run/argocd/argocd-cmp-server]
          image: mozilla/sops:v3-alpine
          securityContext:
            runAsNonRoot: true
            runAsUser: 999
          env:
            - name: SOPS_AGE_KEY_FILE
              value: /sops/private.key
          volumeMounts:
            - mountPath: /var/run/argocd
              name: var-files
            - mountPath: /home/argocd/cmp-server/plugins
              name: plugins
            - mountPath: /home/argocd/cmp-server/config/plugin.yaml
              subPath: plugin.yaml
              name: plugin-plain-and-encrypted-yaml-files
            - mountPath: /sops
              name: sops-private-key
  YAML
}

resource "kubectl_manifest" "argocd_namespace" {
  wait = true

  yaml_body = <<-YAML
    apiVersion: v1
    kind: Namespace
    metadata:
      name: ${var.namespace}
  YAML
}

resource "kubectl_manifest" "sops_private_key" {
  depends_on = [kubectl_manifest.argocd_namespace]

  yaml_body = <<-YAML
    apiVersion: v1
    kind: Secret
    type: Opaque
    metadata:
      name: sops-private-key
      namespace: ${var.namespace}
    data:
      private.key: ${base64encode(var.sops_private_key)}
  YAML
}

resource "kubectl_manifest" "plugin_plain_and_encrypted_yaml_files" {
  depends_on = [kubectl_manifest.argocd_namespace]

  yaml_body = <<-YAML
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: plugin-plain-and-encrypted-yaml-files
      namespace: ${var.namespace}
    data:
      plugin.yaml: |
        apiVersion: argoproj.io/v1alpha1
        kind: ConfigManagementPlugin
        metadata:
          name: plain-and-encrypted-yaml-files
        spec:
          generate:
            command: [
              sh, -c,
              "find . -name '*.yaml' | xargs -n1 -I{} sh -c 'if [ $(grep -e apiVersion -e kind {} | wc -l) -eq 2 ]; then echo --- ; sops -d {} 2>/dev/null || cat {}; fi'"
            ]
  YAML
}

resource "helm_release" "argocd" {
  depends_on = [kubectl_manifest.sops_private_key]

  name       = "argocd"
  chart      = "argo-cd"
  version    = "5.46.7"
  repository = "https://argoproj.github.io/argo-helm"
  namespace  = var.namespace

  values = [local.argocd_values]
}

data "kubernetes_secret" "argocd_initial_admin_password" {
  depends_on = [helm_release.argocd]

  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = var.namespace
  }
}
