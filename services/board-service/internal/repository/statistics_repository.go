package repository

import (
	"context"
	"time"

	"gorm.io/gorm"

	"project-board-api/internal/domain"
)

// StatisticsRepository handles statistics data access
type StatisticsRepository struct {
	db *gorm.DB
}

// NewStatisticsRepository creates a new StatisticsRepository
func NewStatisticsRepository(db *gorm.DB) *StatisticsRepository {
	return &StatisticsRepository{db: db}
}

// CountTotalProjects returns total number of projects
func (r *StatisticsRepository) CountTotalProjects(ctx context.Context) (int64, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&domain.Project{}).Count(&count).Error
	return count, err
}

// CountTotalBoards returns total number of boards
func (r *StatisticsRepository) CountTotalBoards(ctx context.Context) (int64, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&domain.Board{}).Count(&count).Error
	return count, err
}

// CountProjectsCreatedSince returns number of projects created since the given time
func (r *StatisticsRepository) CountProjectsCreatedSince(ctx context.Context, since time.Time) (int64, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&domain.Project{}).
		Where("created_at >= ?", since).Count(&count).Error
	return count, err
}

// CountBoardsCreatedSince returns number of boards created since the given time
func (r *StatisticsRepository) CountBoardsCreatedSince(ctx context.Context, since time.Time) (int64, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&domain.Board{}).
		Where("created_at >= ?", since).Count(&count).Error
	return count, err
}

// CountTodayProjects returns number of projects created today
func (r *StatisticsRepository) CountTodayProjects(ctx context.Context) (int64, error) {
	today := time.Now().Truncate(24 * time.Hour)
	return r.CountProjectsCreatedSince(ctx, today)
}

// CountTodayBoards returns number of boards created today
func (r *StatisticsRepository) CountTodayBoards(ctx context.Context) (int64, error) {
	today := time.Now().Truncate(24 * time.Hour)
	return r.CountBoardsCreatedSince(ctx, today)
}

// GetProjectCreationsByPeriod returns daily project creation counts for the given period
func (r *StatisticsRepository) GetProjectCreationsByPeriod(ctx context.Context, days int) ([]domain.DailyCount, error) {
	var results []domain.DailyCount
	startDate := time.Now().AddDate(0, 0, -days).Truncate(24 * time.Hour)

	err := r.db.WithContext(ctx).Model(&domain.Project{}).
		Select("DATE(created_at) as date, COUNT(*) as count").
		Where("created_at >= ?", startDate).
		Group("DATE(created_at)").
		Order("date ASC").
		Scan(&results).Error

	return results, err
}

// GetBoardCreationsByPeriod returns daily board creation counts for the given period
func (r *StatisticsRepository) GetBoardCreationsByPeriod(ctx context.Context, days int) ([]domain.DailyCount, error) {
	var results []domain.DailyCount
	startDate := time.Now().AddDate(0, 0, -days).Truncate(24 * time.Hour)

	err := r.db.WithContext(ctx).Model(&domain.Board{}).
		Select("DATE(created_at) as date, COUNT(*) as count").
		Where("created_at >= ?", startDate).
		Group("DATE(created_at)").
		Order("date ASC").
		Scan(&results).Error

	return results, err
}
