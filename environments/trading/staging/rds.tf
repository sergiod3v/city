resource "random_password" "db" {
  length  = 32
  special = false
}

# Store generated password in SSM (overwrites PLACEHOLDER set during bootstrap)
resource "aws_ssm_parameter" "db_password" {
  name        = "behemoth.staging.db.password"
  type        = "SecureString"
  value       = random_password.db.result
  overwrite   = true
  description = "RDS behemoth_app password - managed by Terraform"
}

resource "aws_db_instance" "behemoth" {
  identifier        = "behemoth-staging"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = "behemoth"
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.trading.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible     = false
  multi_az                = false
  deletion_protection     = false
  skip_final_snapshot     = true
  backup_retention_period = 7

  apply_immediately = true
}
