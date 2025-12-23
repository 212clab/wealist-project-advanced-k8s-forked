package service

import (
	"context"

	"go.uber.org/zap"

	"project-board-api/internal/domain"
	"project-board-api/internal/metrics"
	"project-board-api/internal/repository"
)

// StatisticsService handles statistics business logic
type StatisticsService struct {
	statsRepo *repository.StatisticsRepository
	metrics   *metrics.Metrics
	logger    *zap.Logger
}

// NewStatisticsService creates a new StatisticsService
func NewStatisticsService(
	statsRepo *repository.StatisticsRepository,
	metrics *metrics.Metrics,
	logger *zap.Logger,
) *StatisticsService {
	return &StatisticsService{
		statsRepo: statsRepo,
		metrics:   metrics,
		logger:    logger,
	}
}

// GetStatistics returns board service statistics for dashboard
func (s *StatisticsService) GetStatistics(ctx context.Context) (*domain.BoardStatistics, error) {
	stats := &domain.BoardStatistics{}

	// Total projects
	totalProjects, err := s.statsRepo.CountTotalProjects(ctx)
	if err != nil {
		s.logger.Error("Failed to count total projects", zap.Error(err))
		return nil, err
	}
	stats.TotalProjects = totalProjects

	// Total boards
	totalBoards, err := s.statsRepo.CountTotalBoards(ctx)
	if err != nil {
		s.logger.Error("Failed to count total boards", zap.Error(err))
		return nil, err
	}
	stats.TotalBoards = totalBoards

	// Today projects
	todayProjects, err := s.statsRepo.CountTodayProjects(ctx)
	if err != nil {
		s.logger.Error("Failed to count today projects", zap.Error(err))
		return nil, err
	}
	stats.TodayProjects = todayProjects

	// Today boards
	todayBoards, err := s.statsRepo.CountTodayBoards(ctx)
	if err != nil {
		s.logger.Error("Failed to count today boards", zap.Error(err))
		return nil, err
	}
	stats.TodayBoards = todayBoards

	// Daily project creations (last 7 days)
	dailyProjects, err := s.statsRepo.GetProjectCreationsByPeriod(ctx, 7)
	if err != nil {
		s.logger.Error("Failed to get daily project creations", zap.Error(err))
		return nil, err
	}
	stats.DailyProjectCreations = dailyProjects

	// Daily board creations (last 7 days)
	dailyBoards, err := s.statsRepo.GetBoardCreationsByPeriod(ctx, 7)
	if err != nil {
		s.logger.Error("Failed to get daily board creations", zap.Error(err))
		return nil, err
	}
	stats.DailyBoardCreations = dailyBoards

	// Update metrics
	if s.metrics != nil {
		s.metrics.ProjectsTotal.Set(float64(totalProjects))
		s.metrics.BoardsTotal.Set(float64(totalBoards))
	}

	return stats, nil
}
