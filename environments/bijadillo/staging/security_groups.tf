# ─── EC2 security group — public web platform ───

resource "aws_security_group" "ec2" {
  name        = "bijadillo-${var.env}-ec2"
  description = "Bijadillo ${var.env} web platform — HTTP, HTTPS, SSH"
  vpc_id      = data.aws_vpc.default.id

  tags = { Name = "bijadillo-${var.env}-ec2-sg" }

  ingress {
    description = "HTTP — redirect to HTTPS + ACME challenge"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH — key auth enforced"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ─── RDS security group — PostgreSQL from EC2 only ───

resource "aws_security_group" "rds" {
  name        = "mercadillo-${var.env}-rds"
  description = "Mercadillo ${var.env} RDS — Postgres from Bijadillo EC2 only"
  vpc_id      = data.aws_vpc.default.id

  tags = { Name = "mercadillo-${var.env}-rds-sg" }

  ingress {
    description     = "PostgreSQL from Bijadillo EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
