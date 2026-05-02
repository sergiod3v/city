variable "your_ip_cidr" {
  description = "Your home/office IP for SSH access (CIDR, e.g. 1.2.3.4/32)"
  type        = string
  default     = "186.30.138.158/32"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "behemoth_app"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key to upload as EC2 key pair"
  type        = string
  default     = "~/.ssh/id_ed25519_alejocc.pub"
}
