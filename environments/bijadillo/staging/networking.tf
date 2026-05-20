data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Read trading env state to reference its EC2 SG without duplicating resources
data "terraform_remote_state" "trading" {
  backend = "s3"
  config = {
    bucket = "eccensia-tfstate-trading-staging"
    key    = "trading/staging/terraform.tfstate"
    region = "us-east-1"
  }
}

# Open 80/443 on the trading EC2 SG — nginx handles subdomain routing
resource "aws_security_group_rule" "http_inbound" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTP — ACME challenge + redirect to HTTPS"
  security_group_id = data.terraform_remote_state.trading.outputs.ec2_sg_id
}

resource "aws_security_group_rule" "https_inbound" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS — nginx TLS termination"
  security_group_id = data.terraform_remote_state.trading.outputs.ec2_sg_id
}
