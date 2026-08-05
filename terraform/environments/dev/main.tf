terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

module "vpc" {
  source      = "../../modules/vpc"
  environment = "dev"
}

module "security_groups" {
  source      = "../../modules/security-groups"
  vpc_id      = module.vpc.vpc_id
  environment = "dev"
}

module "ecr" {
  source           = "../../modules/ecr"
  environment      = "dev"
  repository_names = ["wallet-service", "compliance-service"]
}

module "iam" {
  source      = "../../modules/iam"
  environment = "dev"
}

module "ecs" {
  source                      = "../../modules/ecs"
  environment                 = "dev"
  vpc_id                      = module.vpc.vpc_id
  private_subnet_id           = module.vpc.private_subnet_id
  ecs_tasks_security_group_id = module.security_groups.ecs_tasks_security_group_id
  task_execution_role_arn     = module.iam.task_execution_role_arn
  wallet_service_image        = "${module.ecr.repository_urls["wallet-service"]}:v1"
  compliance_service_image    = "${module.ecr.repository_urls["compliance-service"]}:v1"
}
