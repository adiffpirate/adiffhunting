output "argocd_initial_credentials" {
  description = "ArgoCD initial credentials (password was auto generated on creation)"
  value = {
    username = "admin"
    password = nonsensitive(data.kubernetes_secret.argocd_initial_admin_password.data.password)
  }
}
