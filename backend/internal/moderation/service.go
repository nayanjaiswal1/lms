package moderation

import (
	"context"
	"errors"
	"fmt"
)

// ErrInvalid signals a request that failed validation before reaching the database.
var ErrInvalid = errors.New("moderation: invalid input")

type Service struct {
	repo *Repo
}

func NewService(repo *Repo) *Service {
	return &Service{repo: repo}
}

// CreateReport validates and files a report against contentID on behalf of
// reporterID — any org member may do this, no permission required. The
// report's org is derived from the content itself (not the caller's claim),
// so a report always lands in the same tenant the content actually belongs
// to.
func (s *Service) CreateReport(ctx context.Context, reporterID, contentType, contentID, reason, description string) (Report, error) {
	if !IsValidContentType(contentType) {
		return Report{}, fmt.Errorf("%w: content_type must be one of wiki_page, course_module", ErrInvalid)
	}
	if !IsValidReason(reason) {
		return Report{}, fmt.Errorf("%w: reason must be one of illegal, copyright, spam, harassment, other", ErrInvalid)
	}

	orgID, err := s.repo.ContentOrgID(ctx, contentType, contentID)
	if err != nil {
		return Report{}, err
	}

	var desc *string
	if description != "" {
		desc = &description
	}
	return s.repo.CreateReport(ctx, Report{
		OrgID:       orgID,
		ReporterID:  reporterID,
		ContentType: contentType,
		ContentID:   contentID,
		Reason:      reason,
		Description: desc,
	})
}

// ListReports returns orgID's reports, optionally filtered. Callers must
// already hold content.moderate (checked by route middleware).
func (s *Service) ListReports(ctx context.Context, orgID string, status, contentType *string) ([]Report, error) {
	return s.repo.ListReports(ctx, orgID, status, contentType)
}

// Resolve transitions reportID's status within orgID. Callers must already
// hold content.moderate (checked by route middleware). Marking a report
// 'removed' also takes down the underlying content — the point of the
// resolution, not a separate step staff has to remember.
func (s *Service) Resolve(ctx context.Context, orgID, reportID, status, resolvedBy, note string) (Report, error) {
	if !IsValidStatus(status) {
		return Report{}, fmt.Errorf("%w: status must be one of pending, reviewing, removed, dismissed", ErrInvalid)
	}
	rp, err := s.repo.GetReport(ctx, orgID, reportID)
	if err != nil {
		return Report{}, err
	}

	var notePtr *string
	if note != "" {
		notePtr = &note
	}
	updated, err := s.repo.Resolve(ctx, orgID, reportID, status, resolvedBy, notePtr)
	if err != nil {
		return Report{}, err
	}

	if status == StatusRemoved {
		if err := s.repo.TakeDownContent(ctx, rp.ContentType, rp.ContentID); err != nil {
			return Report{}, err
		}
	}
	return updated, nil
}
