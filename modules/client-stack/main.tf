# Module: client-stack
# Provisions an isolated automation stack for ONE consulting client.
# Per-client: n8n ECS Fargate task + Secrets Manager namespace.
# Shared: RDS PostgreSQL (per-schema isolation), Redis (per-namespace).
#
# Usage: call once per client with unique client_id.
# terraform apply -var="client_id=dental-clinic-bogota-01"

variable "client_id"          { type = string }  # slug: "dental-clinic-bogota-01"
variable "cluster_arn"        { type = string }
variable "subnet_ids"         { type = list(string) }
variable "vpc_id"             { type = string }
variable "execution_role_arn" { type = string }
variable "n8n_image"          { type = string; default = "n8nio/n8n:latest" }
variable "environment"        { type = string; default = "prod" }

locals {
  name_prefix = "eccensia-client-${var.client_id}"
}

# ── Security group for this client's n8n container ───────────────────────────
resource "aws_security_group" "client" {
  name   = "${local.name_prefix}-sg"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Client      = var.client_id
    ManagedBy   = "terraform"
    Environment = var.environment
  }
}

# ── n8n ECS Task Definition ──────────────────────────────────────────────────
resource "aws_ecs_task_definition" "n8n" {
  family                   = "${local.name_prefix}-n8n"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.execution_role_arn

  container_definitions = jsonencode([{
    name  = "n8n"
    image = var.n8n_image
    portMappings = [{ containerPort = 5678, protocol = "tcp" }]
    environment = [
      { name = "N8N_BASIC_AUTH_ACTIVE", value = "true" },
      { name = "CLIENT_ID", value = var.client_id }
    ]
    secrets = [
      {
        name      = "N8N_BASIC_AUTH_PASSWORD"
        valueFrom = "arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:eccensia/consulting/${var.client_id}/n8n-password"
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/eccensia/consulting/${var.client_id}"
        awslogs-region        = "us-east-1"
        awslogs-stream-prefix = "n8n"
      }
    }
  }])

  tags = {
    Client    = var.client_id
    ManagedBy = "terraform"
  }
}

# ── ECS Service (Fargate Spot for cost efficiency) ───────────────────────────
resource "aws_ecs_service" "n8n" {
  name            = "${local.name_prefix}-n8n"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.n8n.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.client.id]
    assign_public_ip = true
  }

  tags = {
    Client    = var.client_id
    ManagedBy = "terraform"
  }
}

# ── CloudWatch Log Group for this client ─────────────────────────────────────
resource "aws_cloudwatch_log_group" "client" {
  name              = "/eccensia/consulting/${var.client_id}"
  retention_in_days = 30

  tags = { Client = var.client_id }
}

output "service_name"    { value = aws_ecs_service.n8n.name }
output "log_group"       { value = aws_cloudwatch_log_group.client.name }
