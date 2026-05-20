output "ec2_public_ip" {
  description = "Bijadillo EIP — use for SSH and DNS verification"
  value       = aws_eip.bijadillo.public_ip
}

output "ec2_ssh_command" {
  description = "SSH into the Bijadillo instance"
  value       = "ssh -i <key-path> ec2-user@${aws_eip.bijadillo.public_ip}"
}

output "ec2_security_group_id" {
  description = "Add as BIJADILLO_SG_ID GitHub Actions secret"
  value       = aws_security_group.ec2.id
}

output "deploy_role_arn" {
  description = "Add as AWS_ROLE_ARN GitHub Actions secret in mercadillo repo"
  value       = aws_iam_role.deploy.arn
}

output "rds_endpoint" {
  description = "PostgreSQL: postgresql://mercadillo_app:<password>@<this>:5432/mercadillo"
  value       = aws_db_instance.mercadillo.endpoint
}

output "rds_port" {
  value = aws_db_instance.mercadillo.port
}

output "s3_assets_bucket" {
  value = aws_s3_bucket.mercadillo_assets.bucket
}

output "dns_instructions" {
  description = "Set A records at your domain registrar pointing to this IP"
  value       = "Point mercadillo.bijadillo.com → ${aws_eip.bijadillo.public_ip} (A record at registrar)"
}
