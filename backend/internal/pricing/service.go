package pricing

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

// ListByAudience validates the audience query param before hitting the DB —
// the two landing pages always pass one explicitly, so an empty/unknown
// value is a caller bug, not a legitimate "give me nothing" request.
func (s *Service) ListByAudience(ctx context.Context, audience string) ([]Tier, error) {
	if audience != AudienceIndividual && audience != AudienceOrg {
		return nil, fmt.Errorf(`%w: audience must be "individual" or "org"`, ErrInvalid)
	}
	return s.repo.ListByAudience(ctx, audience)
}

func (s *Service) ListAll(ctx context.Context) ([]Tier, error) {
	return s.repo.ListAll(ctx)
}

// Update trims and validates the editable fields of a tier before writing.
// CTAHref is required exactly when the CTA is enabled — a live button with
// nowhere to go, or a disabled "Coming soon" button that silently links
// somewhere, are both admin mistakes worth rejecting at the API boundary
// rather than shipping to the public landing page.
func (s *Service) Update(ctx context.Context, id string, t Tier, updatedBy string) (Tier, error) {
	t.Name = strings.TrimSpace(t.Name)
	t.Price = strings.TrimSpace(t.Price)
	t.BillingNote = strings.TrimSpace(t.BillingNote)
	t.Tagline = strings.TrimSpace(t.Tagline)
	t.CTALabel = strings.TrimSpace(t.CTALabel)

	if t.Name == "" {
		return Tier{}, fmt.Errorf("%w: name is required", ErrInvalid)
	}
	if t.Price == "" {
		return Tier{}, fmt.Errorf("%w: price is required", ErrInvalid)
	}
	if t.Tagline == "" {
		return Tier{}, fmt.Errorf("%w: tagline is required", ErrInvalid)
	}
	if t.CTALabel == "" {
		return Tier{}, fmt.Errorf("%w: cta_label is required", ErrInvalid)
	}

	features := make([]string, 0, len(t.Features))
	for _, f := range t.Features {
		f = strings.TrimSpace(f)
		if f != "" {
			features = append(features, f)
		}
	}
	if len(features) == 0 {
		return Tier{}, fmt.Errorf("%w: at least one feature bullet is required", ErrInvalid)
	}
	t.Features = features

	if t.CTAHref != nil {
		href := strings.TrimSpace(*t.CTAHref)
		if href == "" {
			t.CTAHref = nil
		} else {
			t.CTAHref = &href
		}
	}
	if !t.CTADisabled && t.CTAHref == nil {
		return Tier{}, fmt.Errorf("%w: cta_href is required when the CTA is enabled", ErrInvalid)
	}
	if t.CTADisabled {
		t.CTAHref = nil
	}

	return s.repo.Update(ctx, id, t, updatedBy)
}
