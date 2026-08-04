output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_id" {
  value = module.vpc.public_subnet_id
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