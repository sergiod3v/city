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
