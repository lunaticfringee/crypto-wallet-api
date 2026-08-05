variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_id" {
  type = string
}

variable "ecs_tasks_security_group_id" {
  type = string
}

variable "task_execution_role_arn" {
  type = string
}

variable "wallet_service_image" {
  description = "Full ECR image URI for wallet-service"
  type        = string
}

variable "compliance_service_image" {
  description = "Full ECR image URI for compliance-service"
  type        = string
}

variable "wallet_service_target_group_arn" {
  type = string
}

variable "alb_listener_arn" {
  type = string
}
