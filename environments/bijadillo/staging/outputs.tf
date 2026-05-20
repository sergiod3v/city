output "ec2_public_ip" {
  description = "Trading EC2 EIP — use for SSH and DNS A records"
  value       = data.terraform_remote_state.trading.outputs.ec2_elastic_ip
}

output "deploy_role_arn" {
  description = "Add as AWS_ROLE_ARN GitHub Actions secret in mercadillo repo"
  value       = aws_iam_role.deploy.arn
}

output "s3_assets_bucket" {
  description = "S3 bucket for product images and uploads"
  value       = aws_s3_bucket.mercadillo_assets.bucket
}

output "dns_instructions" {
  description = "Set A records at registrar"
  value       = "Point mercadillo.bijadillo.com → ${data.terraform_remote_state.trading.outputs.ec2_elastic_ip} (A record)"
}
