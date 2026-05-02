output "ec2_elastic_ip" {
  description = "Static IP — use this for Binance API key IP whitelist"
  value       = aws_eip.behemoth.public_ip
}

output "ec2_instance_id" {
  value = aws_instance.behemoth.id
}

output "rds_endpoint" {
  description = "RDS host — put this in PM2 ecosystem.config.js DB_HOST"
  value       = aws_db_instance.behemoth.address
}

output "rds_db_name" {
  value = aws_db_instance.behemoth.db_name
}

output "ssh_command" {
  description = "SSH into staging EC2"
  value       = "ssh -i ~/.ssh/id_ed25519_alejocc ec2-user@${aws_eip.behemoth.public_ip}"
}
