terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "three-tier-web-platform-terraform-state-bucket-mihiringole"
    key          = "global/s3/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.var_region

  default_tags {
    tags = {
      Environment = "Dev"
      Project     = "Resume"
    }
  }
}

# 1. Network Tier
module "network" {
  source          = "./modules/network"
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
}

# 2. Compute Tier
module "compute" {
  source = "./modules/compute"

  vpc_id                 = module.network.vpc_id
  public_subnet_ids      = module.network.public_subnet_ids
  private_app_subnet_ids = module.network.private_app_subnet_ids
  alb_sg_id              = module.network.alb_sg_id
  ec2_sg_id              = module.network.ec2_sg_id
}

# 3. Database Tier
module "database" {
  source = "./modules/database"

  private_db_subnet_ids = module.network.private_db_subnet_ids
  rds_sg_id             = module.network.rds_sg_id
}