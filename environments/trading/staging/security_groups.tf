resource "aws_security_group" "ec2" {
  name        = "behemoth-staging-ec2"
  description = "Behemoth EC2 - SSH from your IP only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from your IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds" {
  name        = "behemoth-staging-rds"
  description = "RDS - PostgreSQL from EC2 SG only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "PostgreSQL from EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }
}
