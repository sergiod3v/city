variable "env" {
  description = "Environment name (staging, prod). Injected via TF_VAR_env in CI."
  type        = string
}

variable "project" {
  description = "Project name for tagging."
  type        = string
  default     = "bijadillo"
}

variable "client" {
  description = "Client identifier."
  type        = string
  default     = "bijadillo"
}

variable "ssh_public_key" {
  description = "Ed25519 public key for EC2 SSH access."
  type        = string
}

variable "db_username" {
  description = "RDS master username."
  type        = string
  default     = "mercadillo_app"
}
