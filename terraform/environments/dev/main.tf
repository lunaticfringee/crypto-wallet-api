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
