terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {
    bucket         = "eccensia-tfstate-consulting-prod"
    key            = "consulting/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "eccensia-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "aiego-agency"
      Environment = "prod"
      Owner       = "alejo"
      ManagedBy   = "terraform"
    }
  }
}

variable "aws_region" { default = "us-east-1" }
variable "vpc_id"     { type = string }
variable "subnet_ids" { type = list(string) }

# ── ECS Cluster (shared across all client stacks) ────────────────────────────
resource "aws_ecs_cluster" "consulting" {
  name = "eccensia-consulting-prod"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "consulting" {
  cluster_name       = aws_ecs_cluster.consulting.name
  capacity_providers = ["FARGATE_SPOT", "FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }
}

# ── Shared RDS PostgreSQL (per-client schema isolation) ──────────────────────
module "shared_db" {
  source      = "../../../modules/rds-postgres"
  identifier  = "consulting-prod"
  db_name     = "consulting"
  environment = "prod"
  project     = "aiego-agency"
  subnet_ids  = var.subnet_ids
  vpc_id      = var.vpc_id
}

# ── Client stacks: add one module block per client ───────────────────────────
# Example -- uncomment and fill when onboarding first client:
#
# module "client_ara_supermarket" {
#   source             = "../../../modules/client-stack"
#   client_id          = "ara-supermarket-bogota-01"
#   cluster_arn        = aws_ecs_cluster.consulting.arn
#   subnet_ids         = var.subnet_ids
#   vpc_id             = var.vpc_id
#   execution_role_arn = data.aws_iam_role.ecs_execution.arn
# }

output "cluster_arn"  { value = aws_ecs_cluster.consulting.arn }
output "db_endpoint"  { value = module.shared_db.endpoint }
