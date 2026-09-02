package project

import (
	"context"
	"errors"
	"strings"
)

var ErrNameEmpty = errors.New("project: name is required")

type Service struct {
	repo *Repo
}

func NewService(repo *Repo) *Service {
	return &Service{repo: repo}
}

func (s *Service) Create(ctx context.Context, userID string, req CreateRequest) (Project, error) {
	req.Name = strings.TrimSpace(req.Name)
	if req.Name == "" {
		return Project{}, ErrNameEmpty
	}
	return s.repo.Create(ctx, userID, req)
}

func (s *Service) List(ctx context.Context, userID string) ([]Project, error) {
	return s.repo.ListByUser(ctx, userID)
}
