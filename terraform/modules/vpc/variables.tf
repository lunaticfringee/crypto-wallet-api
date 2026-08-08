variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}

variable "cost_center" {
  description = "Cost center tag for billing"
  type        = string
  default     = "engineering-learning"
}
