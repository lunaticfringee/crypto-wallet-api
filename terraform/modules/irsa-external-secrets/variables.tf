variable "environment" {
  type = string
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the EKS cluster's OIDC provider"
}

variable "oidc_issuer_url" {
  type        = string
  description = "OIDC issuer URL, without https:// prefix"
}

variable "secret_arns" {
  type        = list(string)
  description = "List of Secrets Manager ARNs this role can read"
}
