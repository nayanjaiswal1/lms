package focuswall

import (
	"context"
	"errors"
	"strings"
	"unicode/utf8"
)

var (
	ErrTextEmpty         = errors.New("focuswall: text is required")
	ErrTextTooLong       = errors.New("focuswall: text exceeds 500 characters")
	ErrInvalidColor      = errors.New("focuswall: invalid color")
	ErrInvalidCat        = errors.New("focuswall: invalid category")
	ErrCategoryNameEmpty = errors.New("focuswall: category name is required")
	ErrCategoryTooLong   = errors.New("focuswall: category name exceeds 24 characters")
	ErrCategoryBuiltIn   = errors.New("focuswall: category name collides with a built-in category")
)

const (
	maxTextLength         = 500
	maxCategoryNameLength = 24
)

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
	if ok, err := s.validCategoryForUser(ctx, userID, req.Category); err != nil {
		return Note{}, err
	} else if !ok {
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
	if req.Category != nil {
		if ok, err := s.validCategoryForUser(ctx, userID, *req.Category); err != nil {
			return Note{}, err
		} else if !ok {
			return Note{}, ErrInvalidCat
		}
	}
	return s.repo.Update(ctx, noteID, userID, req)
}

// validCategoryForUser accepts the three built-ins unconditionally. In the
// new schema, custom categories are derived from notes directly (no separate
// category management), so any non-built-in string is allowed.
func (s *Service) validCategoryForUser(ctx context.Context, userID string, c Category) (bool, error) {
	// All categories are valid — built-ins are always allowed, and custom
	// categories are inferred from the notes themselves.
	return true, nil
}

// ListCategories returns the user's custom categories.
func (s *Service) ListCategories(ctx context.Context, userID string) ([]FocusCategory, error) {
	return s.repo.ListCategories(ctx, userID)
}

// CreateCategory validates and stores a custom category name.
func (s *Service) CreateCategory(ctx context.Context, userID string, req CreateCategoryRequest) (FocusCategory, error) {
	name := strings.TrimSpace(req.Name)
	if name == "" {
		return FocusCategory{}, ErrCategoryNameEmpty
	}
	if utf8.RuneCountInString(name) > maxCategoryNameLength {
		return FocusCategory{}, ErrCategoryTooLong
	}
	if isBuiltInCategory(Category(strings.ToLower(name))) {
		return FocusCategory{}, ErrCategoryBuiltIn
	}
	return s.repo.CreateCategory(ctx, userID, name)
}

func (s *Service) DeleteCategory(ctx context.Context, userID, categoryID string) error {
	return s.repo.DeleteCategory(ctx, userID, categoryID)
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
