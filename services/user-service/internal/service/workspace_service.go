// Package service는 user-service의 비즈니스 로직을 구현합니다.
//
// 이 파일은 워크스페이스 CRUD 관련 비즈니스 로직을 포함합니다.
// 멤버 관리 및 참여 요청은 workspace_member_service.go에서 처리합니다.
package service

import (
	"time"

	"github.com/google/uuid"
	"go.uber.org/zap"

	"user-service/internal/domain"
	"user-service/internal/metrics"
	"user-service/internal/repository"
	"user-service/internal/response"
)

// WorkspaceService는 워크스페이스 비즈니스 로직을 처리합니다.
// 워크스페이스 생성, 조회, 수정, 삭제 등의 비즈니스 로직을 처리합니다.
// 메트릭과 로깅을 통해 모니터링을 지원합니다.
type WorkspaceService struct {
	workspaceRepo *repository.WorkspaceRepository
	memberRepo    *repository.WorkspaceMemberRepository
	joinReqRepo   *repository.JoinRequestRepository
	profileRepo   *repository.UserProfileRepository
	userRepo      *repository.UserRepository
	logger        *zap.Logger
	metrics       *metrics.Metrics // 메트릭 수집을 위한 필드
}

// NewWorkspaceService는 새 WorkspaceService를 생성합니다.
// metrics 파라미터가 nil인 경우에도 안전하게 동작합니다.
func NewWorkspaceService(
	workspaceRepo *repository.WorkspaceRepository,
	memberRepo *repository.WorkspaceMemberRepository,
	joinReqRepo *repository.JoinRequestRepository,
	profileRepo *repository.UserProfileRepository,
	userRepo *repository.UserRepository,
	logger *zap.Logger,
	m *metrics.Metrics,
) *WorkspaceService {
	return &WorkspaceService{
		workspaceRepo: workspaceRepo,
		memberRepo:    memberRepo,
		joinReqRepo:   joinReqRepo,
		profileRepo:   profileRepo,
		userRepo:      userRepo,
		logger:        logger,
		metrics:       m,
	}
}

// CreateWorkspace는 새 워크스페이스를 생성합니다.
// 사용자 존재 여부를 확인하고, 워크스페이스 생성 후 소유자를 멤버로 추가합니다.
func (s *WorkspaceService) CreateWorkspace(ownerID uuid.UUID, req domain.CreateWorkspaceRequest) (*domain.Workspace, error) {
	// 💡 워크스페이스 생성 전 사용자 존재 확인
	// OAuth 로그인 시 사용자 동기화 실패를 방지합니다.
	exists, err := s.userRepo.Exists(ownerID)
	if err != nil {
		s.logger.Error("사용자 존재 확인 실패", zap.Error(err))
		return nil, response.NewInternalError("Failed to verify user", "please try logging in again")
	}
	if !exists {
		s.logger.Warn("사용자 DB에 없음, OAuth 동기화 실패 가능성",
			zap.String("user_id", ownerID.String()))
		return nil, response.NewNotFoundError("User not found", "please log out and log in again to sync your account")
	}

	// 기본값 설정: 모두 true
	isPublic := true
	if req.IsPublic != nil {
		isPublic = *req.IsPublic
	}
	needApproved := true
	if req.NeedApproved != nil {
		needApproved = *req.NeedApproved
	}

	workspace := &domain.Workspace{
		ID:                   uuid.New(),
		OwnerID:              ownerID,
		WorkspaceName:        req.WorkspaceName,
		WorkspaceDescription: req.WorkspaceDescription,
		IsPublic:             isPublic,
		NeedApproved:         needApproved,
		OnlyOwnerCanInvite:   true,
		IsActive:             true,
		CreatedAt:            time.Now(),
	}

	if err := s.workspaceRepo.Create(workspace); err != nil {
		s.logger.Error("워크스페이스 생성 실패", zap.Error(err))
		return nil, err
	}

	// 메트릭 기록: 워크스페이스 생성 성공
	if s.metrics != nil {
		s.metrics.RecordWorkspaceCreated()
	}

	// 소유자를 멤버로 추가
	member := &domain.WorkspaceMember{
		ID:          uuid.New(),
		WorkspaceID: workspace.ID,
		UserID:      ownerID,
		RoleName:    domain.RoleOwner,
		IsDefault:   true,
		IsActive:    true,
		JoinedAt:    time.Now(),
		UpdatedAt:   time.Now(),
	}
	if err := s.memberRepo.Create(member); err != nil {
		s.logger.Error("워크스페이스 멤버 생성 실패", zap.Error(err))
		// TODO: 워크스페이스 생성 롤백 필요?
	}

	// 소유자 프로필 생성
	user, err := s.userRepo.FindByID(ownerID)
	if err == nil {
		// 기본 닉네임: 사용자 이름, 없으면 이메일
		defaultNickName := user.Name
		if defaultNickName == "" {
			defaultNickName = user.Email
		}
		profile := &domain.UserProfile{
			ID:          uuid.New(),
			UserID:      ownerID,
			WorkspaceID: workspace.ID,
			NickName:    defaultNickName,
			Email:       user.Email,
			CreatedAt:   time.Now(),
			UpdatedAt:   time.Now(),
		}
		if err := s.profileRepo.Create(profile); err != nil {
			s.logger.Error("소유자 프로필 생성 실패", zap.Error(err))
		}
	}

	s.logger.Info("워크스페이스 생성 완료",
		zap.String("workspace_id", workspace.ID.String()),
		zap.String("owner_id", ownerID.String()),
	)
	return workspace, nil
}

// GetWorkspace는 ID로 워크스페이스를 조회합니다.
func (s *WorkspaceService) GetWorkspace(id uuid.UUID) (*domain.Workspace, error) {
	return s.workspaceRepo.FindByID(id)
}

// GetWorkspaceWithOwner는 소유자 정보를 포함한 워크스페이스를 조회합니다.
func (s *WorkspaceService) GetWorkspaceWithOwner(id uuid.UUID) (*domain.Workspace, error) {
	return s.workspaceRepo.FindByIDWithOwner(id)
}

// GetUserWorkspaces는 사용자가 속한 모든 워크스페이스를 조회합니다.
func (s *WorkspaceService) GetUserWorkspaces(userID uuid.UUID) ([]domain.WorkspaceMember, error) {
	return s.memberRepo.FindByUser(userID)
}

// GetWorkspacesByOwner는 소유자의 워크스페이스 목록을 조회합니다.
func (s *WorkspaceService) GetWorkspacesByOwner(ownerID uuid.UUID) ([]domain.Workspace, error) {
	return s.workspaceRepo.FindByOwnerID(ownerID)
}

// SearchPublicWorkspaces는 이름으로 공개 워크스페이스를 검색합니다.
func (s *WorkspaceService) SearchPublicWorkspaces(name string) ([]domain.Workspace, error) {
	return s.workspaceRepo.FindPublicByName(name)
}

// UpdateWorkspace는 워크스페이스를 업데이트합니다.
// 소유자만 업데이트할 수 있습니다.
func (s *WorkspaceService) UpdateWorkspace(id uuid.UUID, userID uuid.UUID, req domain.UpdateWorkspaceRequest) (*domain.Workspace, error) {
	workspace, err := s.workspaceRepo.FindByID(id)
	if err != nil {
		return nil, err
	}

	// 소유자 확인
	if workspace.OwnerID != userID {
		return nil, response.NewForbiddenError("Only owner can update workspace", "")
	}

	if req.WorkspaceName != nil {
		workspace.WorkspaceName = *req.WorkspaceName
	}
	if req.WorkspaceDescription != nil {
		workspace.WorkspaceDescription = req.WorkspaceDescription
	}
	if req.IsPublic != nil {
		workspace.IsPublic = *req.IsPublic
	}
	if req.NeedApproved != nil {
		workspace.NeedApproved = *req.NeedApproved
	}

	if err := s.workspaceRepo.Update(workspace); err != nil {
		s.logger.Error("워크스페이스 업데이트 실패", zap.Error(err))
		return nil, err
	}

	s.logger.Info("워크스페이스 업데이트 완료",
		zap.String("workspace_id", workspace.ID.String()),
	)
	return workspace, nil
}

// UpdateWorkspaceSettings는 워크스페이스 설정을 업데이트합니다.
// 소유자만 설정을 변경할 수 있습니다.
func (s *WorkspaceService) UpdateWorkspaceSettings(id uuid.UUID, userID uuid.UUID, req domain.UpdateWorkspaceSettingsRequest) (*domain.Workspace, error) {
	workspace, err := s.workspaceRepo.FindByID(id)
	if err != nil {
		return nil, err
	}

	// 소유자 확인
	if workspace.OwnerID != userID {
		return nil, response.NewForbiddenError("Only owner can update workspace settings", "")
	}

	if req.WorkspaceName != nil {
		workspace.WorkspaceName = *req.WorkspaceName
	}
	if req.WorkspaceDescription != nil {
		workspace.WorkspaceDescription = req.WorkspaceDescription
	}
	if req.IsPublic != nil {
		workspace.IsPublic = *req.IsPublic
	}
	if req.RequiresApproval != nil {
		workspace.NeedApproved = *req.RequiresApproval
	}
	if req.OnlyOwnerCanInvite != nil {
		workspace.OnlyOwnerCanInvite = *req.OnlyOwnerCanInvite
	}

	if err := s.workspaceRepo.Update(workspace); err != nil {
		s.logger.Error("워크스페이스 설정 업데이트 실패", zap.Error(err))
		return nil, err
	}

	s.logger.Info("워크스페이스 설정 업데이트 완료",
		zap.String("workspace_id", workspace.ID.String()),
	)
	return workspace, nil
}

// DeleteWorkspace는 워크스페이스를 소프트 삭제합니다.
// 소유자만 삭제할 수 있습니다.
func (s *WorkspaceService) DeleteWorkspace(id uuid.UUID, userID uuid.UUID) error {
	workspace, err := s.workspaceRepo.FindByID(id)
	if err != nil {
		return err
	}

	// 소유자 확인
	if workspace.OwnerID != userID {
		return response.NewForbiddenError("Only owner can delete workspace", "")
	}

	if err := s.workspaceRepo.SoftDelete(id); err != nil {
		s.logger.Error("워크스페이스 삭제 실패", zap.Error(err))
		return err
	}

	s.logger.Info("워크스페이스 삭제 완료",
		zap.String("workspace_id", id.String()),
	)
	return nil
}

// SetDefaultWorkspace는 사용자의 기본 워크스페이스를 설정합니다.
func (s *WorkspaceService) SetDefaultWorkspace(userID, workspaceID uuid.UUID) error {
	// 멤버 확인
	isMember, err := s.memberRepo.IsMember(workspaceID, userID)
	if err != nil {
		return err
	}
	if !isMember {
		return response.NewForbiddenError("User is not a member of this workspace", "")
	}

	return s.memberRepo.SetDefault(userID, workspaceID)
}

// CountTotal returns total number of active workspaces
func (s *WorkspaceService) CountTotal() (int64, error) {
	count, err := s.workspaceRepo.CountTotal()
	if err != nil {
		s.logger.Error("Failed to count total workspaces", zap.Error(err))
		return 0, err
	}

	// Update metrics
	if s.metrics != nil {
		s.metrics.SetWorkspacesTotal(count)
	}

	return count, nil
}
