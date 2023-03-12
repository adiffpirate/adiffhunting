terraform {
  backend "kubernetes" {
    secret_suffix = "argocd"
    config_path   = "~/.kube/config"
  }
}
