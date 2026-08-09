variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  description = "Private subnets for EKS nodes — needs at least 2, different AZs"
  type        = list(string)
}
