package focuswall

import (
	"context"
	"errors"
	"strings"
)

var (
	ErrTextEmpty    = errors.New("focuswall: text is required")
	ErrTextTooLong  = errors.New("focuswall: text exceeds 500 characters")
	ErrInvalidColor = errors.New("focuswall: invalid color")
	ErrInvalidCat   = errors.New("focuswall: invalid category")
)

const maxTextLength = 500

type Service struct {
	repo *Repo
}

func NewService(repo *Repo) *Service {
	return &Service{repo: repo}
}

func (s *Service) Create(ctx context.Context, userID string, req CreateRequest) (Note, error) {
	req.Text = strings.TrimSpace(req.Text)
	if req.Color == "" {
		req.Color = ColorYellow
	}
	if req.Category == "" {
		req.Category = CategoryPersonal
	}
	if err := validateText(req.Text); err != nil {
		return Note{}, err
	}
	if !validColor(req.Color) {
		return Note{}, ErrInvalidColor
	}
	if !validCategory(req.Category) {
		return Note{}, ErrInvalidCat
	}
	return s.repo.Create(ctx, userID, req)
}

func (s *Service) Update(ctx context.Context, userID, noteID string, req UpdateRequest) (Note, error) {
	if req.Text != nil {
		trimmed := strings.TrimSpace(*req.Text)
		if err := validateText(trimmed); err != nil {
			return Note{}, err
		}
		req.Text = &trimmed
	}
	if req.Color != nil && !validColor(*req.Color) {
		return Note{}, ErrInvalidColor
	}
	if req.Category != nil && !validCategory(*req.Category) {
		return Note{}, ErrInvalidCat
	}
	return s.repo.Update(ctx, noteID, userID, req)
}

func (s *Service) Delete(ctx context.Context, userID, noteID string) error {
	return s.repo.Delete(ctx, noteID, userID)
}

func (s *Service) ListMine(ctx context.Context, userID string) ([]Note, error) {
	return s.repo.ListByUser(ctx, userID)
}

func validateText(text string) error {
	if text == "" {
		return ErrTextEmpty
	}
	if len(text) > maxTextLength {
		return ErrTextTooLong
	}
	return nil
}
