terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "eccensia-tfstate-shared"
    key            = "networking/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "eccensia-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Owner      = "alejo"
      ManagedBy  = "terraform"
      Project    = "eccensia-shared"
    }
  }
}

# ── Trading VPC ──────────────────────────────────────────────────────────────
module "trading_vpc" {
  source      = "../../modules/networking"
  name        = "trading"
  cidr        = "10.10.0.0/16"
  environment = "prod"
}

# ── Consulting VPC ───────────────────────────────────────────────────────────
module "consulting_vpc" {
  source      = "../../modules/networking"
  name        = "consulting"
  cidr        = "10.20.0.0/16"
  environment = "prod"
}
