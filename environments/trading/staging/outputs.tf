output "ec2_elastic_ip" {
  description = "Static IP — whitelist this on Binance API key"
  value       = aws_eip.behemoth.public_ip
}

output "ec2_instance_id" {
  value = aws_instance.behemoth.id
}

output "ssh_command" {
  description = "SSH into the bot EC2"
  value       = "ssh -i ~/.ssh/id_ed25519_alejocc ec2-user@${aws_eip.behemoth.public_ip}"
}

output "ec2_sg_id" {
  description = "Trading EC2 security group — referenced by bijadillo env to add 80/443 rules"
  value       = aws_security_group.ec2.id
}
