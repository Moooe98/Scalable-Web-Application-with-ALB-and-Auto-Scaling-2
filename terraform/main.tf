################################################################################
# Root Module — Scalable Web Application with ALB and Auto Scaling
# Account: 920810905747  |  Region: us-east-1
################################################################################

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket         = "scalable-web-app-tfstate-920810905747"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "scalable-web-app-tfstate-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "ScalableWebApp"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "Moooe98"
    }
  }
}

# Secondary provider for CloudFront WAF (must be us-east-1)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "ScalableWebApp"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

################################################################################
# Data Sources
################################################################################

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "./modules/vpc"

  project_name        = var.project_name
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  availability_zones  = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnet_cidrs = var.public_subnet_cidrs
  private_app_cidrs   = var.private_app_subnet_cidrs
  private_db_cidrs    = var.private_db_subnet_cidrs
}

################################################################################
# Security Groups Module
################################################################################

module "security_groups" {
  source = "./modules/security_groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  vpc_cidr     = var.vpc_cidr
}

################################################################################
# SSM IAM Role (created before EC2 so instances can use it)
################################################################################

module "ssm" {
  source = "./modules/ssm"

  project_name = var.project_name
  environment  = var.environment
}

################################################################################
# ALB Module
################################################################################

module "alb" {
  source = "./modules/alb"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id
  certificate_arn   = var.acm_certificate_arn
}

################################################################################
# WAF Module (attached to ALB)
################################################################################

module "waf" {
  source = "./modules/waf"

  project_name = var.project_name
  environment  = var.environment
  alb_arn      = module.alb.alb_arn
}

################################################################################
# EC2 + Auto Scaling Module
################################################################################

module "ec2_asg" {
  source = "./modules/ec2_asg"

  project_name          = var.project_name
  environment           = var.environment
  ami_id                = data.aws_ami.amazon_linux_2023.id
  instance_type         = var.instance_type
  private_subnet_ids    = module.vpc.private_app_subnet_ids
  ec2_sg_id             = module.security_groups.ec2_sg_id
  target_group_arn      = module.alb.target_group_arn
  ssm_instance_profile  = module.ssm.instance_profile_name
  asg_min_size          = var.asg_min_size
  asg_max_size          = var.asg_max_size
  asg_desired_capacity  = var.asg_desired_capacity
  rds_endpoint          = module.rds.rds_endpoint
  db_name               = var.db_name
  db_username           = var.db_username
  db_password           = var.db_password
  alb_arn_suffix        = module.alb.alb_arn_suffix
  tg_arn_suffix         = module.alb.target_group_arn_suffix
}

################################################################################
# RDS Multi-AZ Module
################################################################################

module "rds" {
  source = "./modules/rds"

  project_name        = var.project_name
  environment         = var.environment
  db_subnet_ids       = module.vpc.private_db_subnet_ids
  rds_sg_id           = module.security_groups.rds_sg_id
  db_name             = var.db_name
  db_username         = var.db_username
  db_password         = var.db_password
  db_instance_class   = var.db_instance_class
  db_engine_version   = var.db_engine_version
}

################################################################################
# CloudFront Distribution
################################################################################

module "cloudfront" {
  source = "./modules/cloudfront"

  project_name    = var.project_name
  environment     = var.environment
  alb_dns_name    = module.alb.alb_dns_name
  certificate_arn = var.cloudfront_certificate_arn
}

################################################################################
# Route 53 (optional — skip if no domain)
################################################################################

module "route53" {
  source = "./modules/route53"
  count  = var.domain_name != "" ? 1 : 0

  project_name        = var.project_name
  environment         = var.environment
  domain_name         = var.domain_name
  cloudfront_domain   = module.cloudfront.cloudfront_domain_name
  cloudfront_zone_id  = module.cloudfront.cloudfront_hosted_zone_id
  alb_dns_name        = module.alb.alb_dns_name
  alb_zone_id         = module.alb.alb_zone_id
}

################################################################################
# Monitoring — CloudWatch + SNS
################################################################################

module "monitoring" {
  source = "./modules/monitoring"

  project_name      = var.project_name
  environment       = var.environment
  aws_region        = var.aws_region
  alb_arn_suffix    = module.alb.alb_arn_suffix
  tg_arn_suffix     = module.alb.target_group_arn_suffix
  asg_name          = module.ec2_asg.asg_name
  rds_identifier    = module.rds.rds_identifier
  sns_email         = var.sns_alarm_email
}

