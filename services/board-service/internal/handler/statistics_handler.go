package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"project-board-api/internal/response"
	"project-board-api/internal/service"
)

// StatisticsHandler handles statistics HTTP requests
type StatisticsHandler struct {
	statisticsService *service.StatisticsService
}

// NewStatisticsHandler creates a new StatisticsHandler
func NewStatisticsHandler(statisticsService *service.StatisticsService) *StatisticsHandler {
	return &StatisticsHandler{statisticsService: statisticsService}
}

// GetStatistics godoc
// @Summary Get board service statistics for dashboard
// @Tags Statistics
// @Produce json
// @Success 200 {object} domain.BoardStatistics
// @Failure 500 {object} response.ErrorResponse
// @Router /statistics/boards [get]
func (h *StatisticsHandler) GetStatistics(c *gin.Context) {
	stats, err := h.statisticsService.GetStatistics(c.Request.Context())
	if err != nil {
		response.SendError(c, http.StatusInternalServerError, response.ErrCodeInternal, "Failed to get board statistics")
		return
	}

	c.JSON(http.StatusOK, stats)
}
