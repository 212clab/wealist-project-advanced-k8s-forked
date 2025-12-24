# =============================================================================
# Variables for Secrets Manager Module
# =============================================================================

variable "secrets" {
  description = "Map of secrets to create. Key is secret name, value contains description and secret_string"
  type = map(object({
    description   = optional(string, "Managed by Terraform")
    secret_string = string
    tags          = optional(map(string), {})
  }))
  default = {}
}

variable "recovery_window_in_days" {
  description = "Number of days to retain deleted secrets (0 for immediate deletion)"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags to apply to all secrets"
  type        = map(string)
  default     = {}
}
