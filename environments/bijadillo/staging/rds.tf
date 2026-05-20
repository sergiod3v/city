data "aws_ssm_parameter" "db_password" {
  name            = "/mercadillo/${var.env}/db/password"
  with_decryption = true
}

resource "aws_db_subnet_group" "mercadillo" {
  name       = "mercadillo-${var.env}"
  subnet_ids = data.aws_subnets.default.ids
  tags       = { Name = "mercadillo-${var.env}-subnet-group" }
}

resource "aws_db_instance" "mercadillo" {
  identifier = "mercadillo-${var.env}"

  engine         = "postgres"
  engine_version = "16.3"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 50 # auto-scaling cap — won't exceed without explicit change
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = "mercadillo"
  username = var.db_username
  password = data.aws_ssm_parameter.db_password.value

  db_subnet_group_name   = aws_db_subnet_group.mercadillo.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false # EC2 is same VPC — no public access needed

  backup_retention_period = 3
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  deletion_protection = false # staging only — set true for prod
  skip_final_snapshot = true  # staging only

  # Enforce SSL connections
  parameter_group_name = aws_db_parameter_group.mercadillo.name

  tags = { Name = "mercadillo-${var.env}-postgres" }
}

resource "aws_db_parameter_group" "mercadillo" {
  name   = "mercadillo-${var.env}-pg16"
  family = "postgres16"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "immediate"
  }

  tags = { Name = "mercadillo-${var.env}-param-group" }
}
