variable "environment" {
  type = string
}

variable "secret_name" {
  type        = string
  description = "Name suffix for the secret, e.g. wallet-service/infura-url"
}
