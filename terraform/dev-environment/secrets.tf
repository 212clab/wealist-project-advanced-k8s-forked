# =============================================================================
# AWS Secrets Manager - Dev Environment Secrets
# =============================================================================
# 모든 시크릿은 AWS 기본 KMS 키로 암호화됨
#
# 사용법:
#   1. terraform.tfvars에 시크릿 값 설정
#   2. terraform apply
#   3. External Secrets Operator로 K8s에서 사용
#
# 시크릿 경로 규칙: wealist/{environment}/{secret-name}

# -----------------------------------------------------------------------------
# Secrets Manager Module
# -----------------------------------------------------------------------------
module "secrets" {
  source = "../modules/secrets-manager"

  recovery_window_in_days = 0  # Dev 환경: 즉시 삭제 가능

  secrets = {
    # -------------------------------------------------------------------------
    # Google OAuth
    # -------------------------------------------------------------------------
    "wealist/dev/google-oauth" = {
      description = "Google OAuth2 credentials for wealist dev environment"
      secret_string = jsonencode({
        client_id     = var.google_client_id
        client_secret = var.google_client_secret
      })
    }

    # -------------------------------------------------------------------------
    # JWT
    # -------------------------------------------------------------------------
    "wealist/dev/jwt" = {
      description = "JWT signing secret for wealist dev environment"
      secret_string = jsonencode({
        secret = var.jwt_secret
      })
    }

    # -------------------------------------------------------------------------
    # Database Passwords
    # -------------------------------------------------------------------------
    "wealist/dev/database" = {
      description = "Database passwords for wealist dev environment"
      secret_string = jsonencode({
        superuser_password = var.db_superuser_password
        user_password      = var.db_user_password
        board_password     = var.db_board_password
        chat_password      = var.db_chat_password
        noti_password      = var.db_noti_password
        storage_password   = var.db_storage_password
        video_password     = var.db_video_password
      })
    }

    # -------------------------------------------------------------------------
    # Redis
    # -------------------------------------------------------------------------
    "wealist/dev/redis" = {
      description = "Redis password for wealist dev environment"
      secret_string = jsonencode({
        password = var.redis_password
      })
    }

    # -------------------------------------------------------------------------
    # MinIO / S3
    # -------------------------------------------------------------------------
    "wealist/dev/minio" = {
      description = "MinIO/S3 credentials for wealist dev environment"
      secret_string = jsonencode({
        root_password = var.minio_root_password
        access_key    = var.s3_access_key
        secret_key    = var.s3_secret_key
      })
    }

    # -------------------------------------------------------------------------
    # LiveKit
    # -------------------------------------------------------------------------
    "wealist/dev/livekit" = {
      description = "LiveKit API credentials for wealist dev environment"
      secret_string = jsonencode({
        api_key    = var.livekit_api_key
        api_secret = var.livekit_api_secret
      })
    }

    # -------------------------------------------------------------------------
    # Internal API Key
    # -------------------------------------------------------------------------
    "wealist/dev/internal" = {
      description = "Internal API key for service-to-service communication"
      secret_string = jsonencode({
        api_key = var.internal_api_key
      })
    }
  }

  tags = {
    Environment = "dev"
    Project     = "wealist"
  }
}
