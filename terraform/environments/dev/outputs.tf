output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_id" {
  value = module.vpc.public_subnet_id
}

output "public_subnet_2_id" {
  value = module.vpc.public_subnet_2_id
}

output "private_subnet_id" {
  value = module.vpc.private_subnet_id
}

output "alb_security_group_id" {
  value = module.security_groups.alb_security_group_id
}

output "ecs_tasks_security_group_id" {
  value = module.security_groups.ecs_tasks_security_group_id
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "task_execution_role_arn" {
  value = module.iam.task_execution_role_arn
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}

output "wallet_secret_arn" {
  value = module.secrets.secret_arn
}
