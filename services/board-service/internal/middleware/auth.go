// Package middleware는 HTTP 미들웨어를 제공합니다.
package middleware

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"go.uber.org/zap"

	commonauth "github.com/OrangesCloud/wealist-advanced-go-pkg/auth"
)

// TokenValidator는 JWT 토큰 검증을 위한 인터페이스입니다.
type TokenValidator = commonauth.TokenValidator

// SmartValidator는 auth-service HTTP 검증과 JWKS fallback을 지원합니다.
type SmartValidator = commonauth.SmartValidator

// NewSmartValidator는 새 SmartValidator를 생성합니다.
// authServiceURL: auth-service URL (예: http://auth-service:8080)
// issuer: JWT issuer (예: wealist-auth-service)
func NewSmartValidator(authServiceURL, issuer string, logger *zap.Logger) *SmartValidator {
	return commonauth.NewSmartValidator(authServiceURL, issuer, logger)
}

// AuthWithValidator는 TokenValidator를 사용하여 JWT 토큰을 검증하는 미들웨어입니다.
func AuthWithValidator(validator TokenValidator) gin.HandlerFunc {
	return commonauth.AuthMiddlewareWithValidator(validator)
}

// Auth는 JWT 토큰을 검증하는 미들웨어를 반환합니다.
// Deprecated: SmartValidator를 사용하는 AuthWithValidator 사용 권장
func Auth(jwtSecret string) gin.HandlerFunc {
	return commonauth.JWTMiddleware(jwtSecret)
}

// GetUserID는 컨텍스트에서 사용자 ID를 추출합니다.
func GetUserID(c *gin.Context) (uuid.UUID, bool) {
	return commonauth.GetUserID(c)
}

// GetJWTToken은 컨텍스트에서 JWT 토큰을 추출합니다.
func GetJWTToken(c *gin.Context) (string, bool) {
	return commonauth.GetJWTToken(c)
}
