variable "your_ip_cidr" {
  description = "Your home/office IP for SSH access (CIDR, e.g. 1.2.3.4/32). Passed via TF_VAR_your_ip_cidr in GitHub Actions secret MY_IP_CIDR."
  type        = string
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "behemoth_app"
}

# Content of ~/.ssh/id_ed25519_alejocc.pub
# Passed via TF_VAR_ssh_public_key env var in GitHub Actions (secret: SSH_PUBLIC_KEY)
# Never use file() here — runners don't have the key on disk
variable "ssh_public_key" {
  description = "Ed25519 public key content for EC2 access"
  type        = string
}
