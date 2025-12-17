package errors

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"gorm.io/gorm"
)

// ErrorResponse represents the JSON response structure for errors
type ErrorResponse struct {
	Code    string `json:"code"`
	Message string `json:"message"`
	Details string `json:"details,omitempty"`
}

// Handler provides methods for handling errors in HTTP handlers
type Handler struct {
	logger *zap.Logger
}

// NewHandler creates a new error handler with the given logger
func NewHandler(logger *zap.Logger) *Handler {
	if logger == nil {
		logger = zap.NewNop()
	}
	return &Handler{logger: logger}
}

// HandleError handles an error and sends an appropriate HTTP response.
// It logs the error and converts it to a proper HTTP response.
func (h *Handler) HandleError(c *gin.Context, err error) {
	if err == nil {
		return
	}

	// Log the error
	h.logger.Error("Request error",
		zap.Error(err),
		zap.String("path", c.Request.URL.Path),
		zap.String("method", c.Request.Method))

	// Check for GORM not found error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		h.sendError(c, http.StatusNotFound, ErrCodeNotFound, "Resource not found", "")
		return
	}

	// Check for AppError
	var appErr *AppError
	if errors.As(err, &appErr) {
		h.logger.Debug("AppError details",
			zap.String("code", appErr.Code),
			zap.String("message", appErr.Message),
			zap.String("details", appErr.Details))

		statusCode := GetHTTPStatus(appErr.Code)
		h.sendError(c, statusCode, appErr.Code, appErr.Message, appErr.Details)
		return
	}

	// Default to internal server error
	h.logger.Warn("Unhandled error type",
		zap.String("type", err.Error()),
		zap.Error(err))
	h.sendError(c, http.StatusInternalServerError, ErrCodeInternal, "Internal server error", "")
}

// sendError sends an error response to the client
func (h *Handler) sendError(c *gin.Context, statusCode int, code, message, details string) {
	c.JSON(statusCode, ErrorResponse{
		Code:    code,
		Message: message,
		Details: details,
	})
}

// SendError is a helper function to send an error response without an error handler instance
func SendError(c *gin.Context, statusCode int, code, message string) {
	c.JSON(statusCode, ErrorResponse{
		Code:    code,
		Message: message,
	})
}

// SendErrorWithDetails sends an error response with details
func SendErrorWithDetails(c *gin.Context, statusCode int, code, message, details string) {
	c.JSON(statusCode, ErrorResponse{
		Code:    code,
		Message: message,
		Details: details,
	})
}

// HandleAppError is a convenience function that handles an AppError directly
func HandleAppError(c *gin.Context, err *AppError) {
	if err == nil {
		return
	}
	statusCode := GetHTTPStatus(err.Code)
	c.JSON(statusCode, ErrorResponse{
		Code:    err.Code,
		Message: err.Message,
		Details: err.Details,
	})
}

// GetLoggerFromContext retrieves the logger from gin context
// Returns a nop logger if not found
func GetLoggerFromContext(c *gin.Context) *zap.Logger {
	if logger, exists := c.Get("logger"); exists {
		if log, ok := logger.(*zap.Logger); ok {
			return log
		}
	}
	return zap.NewNop()
}

// HandleServiceError is a convenience function for handling errors from service layer
// It gets the logger from context and handles the error appropriately
func HandleServiceError(c *gin.Context, err error) {
	logger := GetLoggerFromContext(c)
	handler := NewHandler(logger)
	handler.HandleError(c, err)
}
