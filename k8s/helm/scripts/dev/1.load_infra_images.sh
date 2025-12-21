#!/bin/bash
# =============================================================================
# 인프라 이미지 확인 (dev 환경 - GHCR)
# =============================================================================
# dev 환경은 외부 DB (AWS RDS/ElastiCache)를 사용하므로
# PostgreSQL/Redis 이미지 로드가 필요 없습니다.
#
# 이 스크립트는 GHCR 연결 확인용으로만 사용됩니다.

set -e

GHCR_REGISTRY="ghcr.io/orangescloud"

echo "=== dev 환경 인프라 확인 (GHCR) ==="
echo ""
echo "📦 Registry: ${GHCR_REGISTRY}"
echo ""
echo "ℹ️  dev 환경 구성:"
echo "   - PostgreSQL: AWS RDS (외부)"
echo "   - Redis: AWS ElastiCache (외부)"
echo "   - Frontend: S3 + CloudFront (CDN)"
echo "   - Backend: GHCR 이미지 → EKS"
echo ""

# GHCR 인증 확인
echo "🔐 GHCR 인증 확인 중..."
if docker pull ${GHCR_REGISTRY}/auth-service:latest 2>/dev/null; then
    echo "✅ GHCR 접근 가능"
else
    echo "⚠️  GHCR 접근 불가 - 로그인이 필요할 수 있습니다."
    echo ""
    echo "   GHCR 로그인:"
    echo "   echo \$GHCR_TOKEN | docker login ghcr.io -u \$GHCR_USERNAME --password-stdin"
fi

echo ""
echo "✅ 인프라 확인 완료!"
echo ""
echo "📝 다음 단계:"
echo "   1. 서비스 이미지 빌드 및 GHCR 푸시:"
echo "      ./2.build_and_push_ghcr.sh"
echo ""
echo "   2. Helm 배포:"
echo "      make helm-install-all ENV=dev"
