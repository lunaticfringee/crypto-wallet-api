variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "cluster_subnet_ids" {
  description = "Subnets used for EKS cluster VPC networking"
  type        = list(string)
}

variable "node_subnet_ids" {
  description = "Subnets where EKS worker nodes are launched"
  type        = list(string)
}
