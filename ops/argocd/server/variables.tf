variable "namespace" {
  description = "Kubernetes Namespace where ArgoCD will be installed"
  type        = string
  default     = "argocd"
}

variable "target_revision" {
  description = "Git revision to use for adiffhunting repository"
  type        = string
  default     = "master"
}

variable "sops_private_key" {
  description = "Private key used by SOPS to decrypt secret manifest/values"
  type        = string
  sensitive   = true
}

variable "github_username" {
  description = "Username to authenticate on GitHub"
  type        = string
  default     = "adiffpirate"
}

variable "github_token" {
  description = "Token to authenticate on GitHub"
  type        = string
  sensitive   = true
}
