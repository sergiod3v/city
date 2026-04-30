terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {
    bucket         = "eccensia-tfstate-trading-prod"
    key            = "trading/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "eccensia-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "behemoth"
      Environment = "prod"
      Owner       = "alejo"
      ManagedBy   = "terraform"
    }
  }
}

# ── Variables (values in terraform.tfvars -- never committed) ────────────────
variable "aws_region"    { default = "us-east-1" }
variable "vpc_id"        { type = string }
variable "subnet_id"     { type = string }
variable "ami"           { type = string }
variable "my_ip_cidr"    { type = string }  # "x.x.x.x/32"

# ── Behemoth Bot EC2 ─────────────────────────────────────────────────────────
module "behemoth_bot" {
  source        = "../../../modules/ec2-bot"
  name          = "behemoth"
  instance_type = "t3.small"
  subnet_id     = var.subnet_id
  vpc_id        = var.vpc_id
  ami           = var.ami
  iam_instance_profile = "eccensia-trading-bot"
  environment   = "prod"
  project       = "behemoth"
  allowed_ssh_cidr = var.my_ip_cidr
}

# ── RDS PostgreSQL (bot state: cycles, rungs, events) ────────────────────────
module "bot_db" {
  source      = "../../../modules/rds-postgres"
  identifier  = "behemoth-prod"
  db_name     = "behemoth"
  environment = "prod"
  project     = "behemoth"
  subnet_ids  = [var.subnet_id]
  vpc_id      = var.vpc_id
}

# ── CloudWatch Alarms ─────────────────────────────────────────────────────────
module "monitoring" {
  source       = "../../../modules/cloudwatch-alarms"
  project      = "behemoth"
  environment  = "prod"
  instance_id  = module.behemoth_bot.instance_id
  alert_email  = "sergioa.camachoc@gmail.com"
}

output "bot_ip" { value = module.behemoth_bot.public_ip }
output "db_endpoint" { value = module.bot_db.endpoint }
