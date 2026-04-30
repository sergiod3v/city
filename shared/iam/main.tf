terraform {
  backend "s3" {
    bucket         = "eccensia-tfstate-shared"
    key            = "iam/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "eccensia-tfstate-lock"
    encrypt        = true
  }
}

# ── EC2 instance role (trading bot) ─────────────────────────────────────────
resource "aws_iam_role" "trading_bot" {
  name = "eccensia-trading-bot"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = { Project = "trading" }
}

resource "aws_iam_role_policy_attachment" "trading_bot_ssm" {
  role       = aws_iam_role.trading_bot.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Inline: read own secrets, write CloudWatch logs
resource "aws_iam_role_policy" "trading_bot_inline" {
  name = "trading-bot-policy"
  role = aws_iam_role.trading_bot.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:*:*:secret:eccensia/trading/*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
      }
    ]
  })
}

# ── ECS task execution role (consulting client stacks) ───────────────────────
resource "aws_iam_role" "ecs_task_execution" {
  name = "eccensia-ecs-task-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_secrets" {
  name = "ecs-secrets-read"
  role = aws_iam_role.ecs_task_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = "arn:aws:secretsmanager:*:*:secret:eccensia/consulting/*"
    }]
  })
}
