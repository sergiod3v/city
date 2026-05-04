variable "env" {
  description = "Environment name (staging, prod). Injected via TF_VAR_env in CI."
  type        = string
}

variable "project" {
  description = "Project name for tagging and grouping in AWS."
  type        = string
  default     = "auto-trading"
}

variable "client" {
  description = "Client identifier. 'myself' for personal use, client ID for agency deployments."
  type        = string
  default     = "myself"
}

variable "your_ip_cidr" {
  description = "Your IP for SSH access. Passed via TF_VAR_your_ip_cidr in CI (secret MY_IP_CIDR)."
  type        = string
}

variable "db_username" {
  description = "RDS master username. Unused when SQLite is active."
  type        = string
  default     = "behemoth_app"
}

variable "ssh_public_key" {
  description = "Ed25519 public key content for EC2 access. Passed via TF_VAR_ssh_public_key in CI."
  type        = string
}
