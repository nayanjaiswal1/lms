package whatsnew

import (
	"context"
	"fmt"
	"strings"
)

type Service struct {
	repo *Repo
}

func NewService(repo *Repo) *Service {
	return &Service{repo: repo}
}

func (s *Service) ListPublished(ctx context.Context) ([]Entry, error) {
	return s.repo.ListPublished(ctx)
}

func (s *Service) ListAll(ctx context.Context) ([]Entry, error) {
	return s.repo.ListAll(ctx)
}

func validate(e *Entry) error {
	e.Title = strings.TrimSpace(e.Title)
	e.Description = strings.TrimSpace(e.Description)
	e.CTALabel = strings.TrimSpace(e.CTALabel)
	e.CTAHref = strings.TrimSpace(e.CTAHref)

	if e.Title == "" || len(e.Title) > 120 {
		return fmt.Errorf("%w: title must be 1-120 characters", ErrInvalid)
	}
	if e.Description == "" || len(e.Description) > 500 {
		return fmt.Errorf("%w: description must be 1-500 characters", ErrInvalid)
	}
	if e.CTALabel == "" || len(e.CTALabel) > 40 {
		return fmt.Errorf("%w: cta_label must be 1-40 characters", ErrInvalid)
	}
	if e.CTAHref == "" {
		return fmt.Errorf("%w: cta_href is required", ErrInvalid)
	}
	if _, ok := AllowedIcons[e.Icon]; !ok {
		return fmt.Errorf("%w: icon must be one of the platform's supported icons", ErrInvalid)
	}
	return nil
}

func (s *Service) Create(ctx context.Context, e Entry) (Entry, error) {
	if err := validate(&e); err != nil {
		return Entry{}, err
	}
	return s.repo.Create(ctx, e)
}

func (s *Service) Update(ctx context.Context, id string, e Entry) (Entry, error) {
	if err := validate(&e); err != nil {
		return Entry{}, err
	}
	return s.repo.Update(ctx, id, e)
}

func (s *Service) Delete(ctx context.Context, id string) error {
	return s.repo.Delete(ctx, id)
}
