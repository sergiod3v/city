# Module: ec2-bot
# Provisions an EC2 instance for a long-running bot process.
# Used by: trading/prod (Behemoth), any future always-on bot.

variable "name"            { type = string }
variable "instance_type"   { type = string; default = "t3.small" }
variable "subnet_id"       { type = string }
variable "vpc_id"          { type = string }
variable "ami"             { type = string }
variable "iam_instance_profile" { type = string }
variable "environment"     { type = string }
variable "project"         { type = string }
variable "allowed_ssh_cidr" { type = string; default = "" }  # empty = no SSH ingress

resource "aws_security_group" "bot" {
  name   = "${var.project}-${var.name}-${var.environment}"
  vpc_id = var.vpc_id

  # SSH only if explicitly provided (leave empty to skip)
  dynamic "ingress" {
    for_each = var.allowed_ssh_cidr != "" ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.allowed_ssh_cidr]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.name}-sg"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_instance" "bot" {
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  iam_instance_profile        = var.iam_instance_profile
  vpc_security_group_ids      = [aws_security_group.bot.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y python3.11 git
    pip3 install pm2
    npm install -g pm2
    pm2 startup
  EOF

  tags = {
    Name        = "${var.project}-${var.name}"
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

output "instance_id"  { value = aws_instance.bot.id }
output "public_ip"    { value = aws_instance.bot.public_ip }
output "private_ip"   { value = aws_instance.bot.private_ip }
