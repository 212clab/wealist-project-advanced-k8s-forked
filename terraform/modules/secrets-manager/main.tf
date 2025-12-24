# =============================================================================
# AWS Secrets Manager Module
# =============================================================================
# 시크릿을 AWS Secrets Manager에 저장하는 모듈
# AWS 기본 KMS 키 사용 (aws/secretsmanager)
#
# 사용법:
#   module "secrets" {
#     source = "../modules/secrets-manager"
#     secrets = {
#       "wealist/dev/google-oauth" = {
#         description = "Google OAuth credentials"
#         secret_string = jsonencode({
#           client_id     = var.google_client_id
#           client_secret = var.google_client_secret
#         })
#       }
#     }
#   }

# -----------------------------------------------------------------------------
# Secrets
# -----------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "this" {
  for_each = var.secrets

  name        = each.key
  description = lookup(each.value, "description", "Managed by Terraform")

  # AWS 기본 KMS 키 사용 (kms_key_id를 지정하지 않으면 기본 키 사용)
  # kms_key_id = null  # AWS managed key (aws/secretsmanager)

  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(var.tags, lookup(each.value, "tags", {}))
}

# -----------------------------------------------------------------------------
# Secret Values
# -----------------------------------------------------------------------------
resource "aws_secretsmanager_secret_version" "this" {
  for_each = var.secrets

  secret_id     = aws_secretsmanager_secret.this[each.key].id
  secret_string = each.value.secret_string
}
