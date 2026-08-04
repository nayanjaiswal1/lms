package legal

import (
	"context"
	"errors"
	"fmt"
)

// ErrInvalid signals a request that failed validation before reaching the database.
var ErrInvalid = errors.New("legal: invalid input")

type Service struct {
	repo *Repo
}

func NewService(repo *Repo) *Service {
	return &Service{repo: repo}
}

// Status reports which documents userID still needs to (re-)accept — any
// doc_type where their latest accepted version doesn't match CurrentVersion.
func (s *Service) Status(ctx context.Context, userID string) ([]string, error) {
	var needed []string
	for _, docType := range AllDocTypes {
		latest, err := s.repo.LatestVersion(ctx, userID, docType)
		if err != nil {
			return nil, err
		}
		if latest != CurrentVersion(docType) {
			needed = append(needed, docType)
		}
	}
	return needed, nil
}

// Accept records userID's consent to docType's current version. The version
// is always the server's own CurrentVersion, never client-supplied — the
// client only chooses which document it's accepting, not what "current"
// means, which sidesteps the frontend ever needing to know or duplicate the
// version string.
func (s *Service) Accept(ctx context.Context, userID, docType string, ip *string) (Acceptance, error) {
	if !IsValidDocType(docType) {
		return Acceptance{}, fmt.Errorf("%w: doc_type must be one of terms, privacy", ErrInvalid)
	}
	return s.repo.RecordAcceptance(ctx, userID, docType, CurrentVersion(docType), ip)
}
