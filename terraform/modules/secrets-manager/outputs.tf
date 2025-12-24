# =============================================================================
# Outputs for Secrets Manager Module
# =============================================================================

output "secret_arns" {
  description = "Map of secret names to their ARNs"
  value = {
    for name, secret in aws_secretsmanager_secret.this : name => secret.arn
  }
}

output "secret_ids" {
  description = "Map of secret names to their IDs"
  value = {
    for name, secret in aws_secretsmanager_secret.this : name => secret.id
  }
}

output "secret_names" {
  description = "List of created secret names"
  value       = keys(aws_secretsmanager_secret.this)
}
