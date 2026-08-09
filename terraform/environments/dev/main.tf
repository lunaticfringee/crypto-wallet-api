terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "crypto-wallet-api-terraform-state-798404182966"
    key          = "dev/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
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
  source                          = "../../modules/ecs"
  environment                     = "dev"
  vpc_id                          = module.vpc.vpc_id
  private_subnet_id               = module.vpc.private_subnet_id
  ecs_tasks_security_group_id     = module.security_groups.ecs_tasks_security_group_id
  task_execution_role_arn         = module.iam.task_execution_role_arn
  wallet_service_image            = "${module.ecr.repository_urls["wallet-service"]}:v1"
  compliance_service_image        = "${module.ecr.repository_urls["compliance-service"]}:v1"
  wallet_service_target_group_arn = module.alb.target_group_arn
  alb_listener_arn                = module.alb.http_listener_arn
}

module "alb" {
  source                = "../../modules/alb"
  environment           = "dev"
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = [module.vpc.public_subnet_id, module.vpc.public_subnet_2_id]
  alb_security_group_id = module.security_groups.alb_security_group_id
}

module "eks" {
  source             = "../../modules/eks"
  environment        = "dev"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = [module.vpc.private_subnet_id, module.vpc.private_subnet_2_id]
}
