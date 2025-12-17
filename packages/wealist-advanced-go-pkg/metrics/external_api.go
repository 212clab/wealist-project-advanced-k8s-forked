package metrics

import (
	"time"
)

// RecordExternalAPIRequest records external API request metrics
func (m *Metrics) RecordExternalAPIRequest(endpoint, method string, statusCode int, duration time.Duration) {
	m.safeExecute("RecordExternalAPIRequest", func() {
		status := CategorizeStatus(statusCode)
		m.ExternalAPIRequestsTotal.WithLabelValues(endpoint, method, status).Inc()
		m.ExternalAPIRequestDuration.WithLabelValues(endpoint, status).Observe(duration.Seconds())
	})
}

// RecordExternalAPIError records external API error
func (m *Metrics) RecordExternalAPIError(endpoint, errorType string) {
	m.safeExecute("RecordExternalAPIError", func() {
		m.ExternalAPIErrors.WithLabelValues(endpoint, errorType).Inc()
	})
}

// ExternalAPIErrorType constants for common error types
const (
	ErrorTypeTimeout     = "timeout"
	ErrorTypeConnection  = "connection"
	ErrorTypeDNS         = "dns"
	ErrorTypeTLS         = "tls"
	ErrorTypeRateLimit   = "rate_limit"
	ErrorTypeServerError = "server_error"
	ErrorTypeClientError = "client_error"
	ErrorTypeUnknown     = "unknown"
)

// CategorizeError categorizes an error into a type for metrics
func CategorizeError(err error) string {
	if err == nil {
		return ""
	}

	errStr := err.Error()

	switch {
	case containsAny(errStr, "timeout", "deadline exceeded"):
		return ErrorTypeTimeout
	case containsAny(errStr, "no such host", "dns"):
		return ErrorTypeDNS
	case containsAny(errStr, "connection refused", "connection reset"):
		return ErrorTypeConnection
	case containsAny(errStr, "tls", "certificate"):
		return ErrorTypeTLS
	case containsAny(errStr, "rate limit", "too many requests", "429"):
		return ErrorTypeRateLimit
	default:
		return ErrorTypeUnknown
	}
}

// containsAny checks if s contains any of the substrings
func containsAny(s string, substrings ...string) bool {
	for _, sub := range substrings {
		if len(s) >= len(sub) {
			for i := 0; i <= len(s)-len(sub); i++ {
				if s[i:i+len(sub)] == sub {
					return true
				}
			}
		}
	}
	return false
}
