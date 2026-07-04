package experience

import (
	"context"
	"errors"
	"fmt"
)

// ErrInvalid signals a request that failed validation before reaching the
// database (unknown subject type, missing experience, invalid experience value).
var ErrInvalid = errors.New("experience: invalid input")

type Service struct {
	repo *Repo
}

func NewService(repo *Repo) *Service {
	return &Service{repo: repo}
}

// Submit validates and persists a learner's post-activity experience report.
// Exactly one of (experience, skip) must be set: a real submission requires
// a valid experience value; a skip requires no experience. description is
// always optional — it is most useful when experience is issue or complaint,
// but is not required even then, so a struggling learner in a hurry can still
// flag a problem without writing anything.
func (s *Service) Submit(ctx context.Context, orgID string, subjectType SubjectType, subjectID, userID string, exp *Experience, description *string, skip bool) (Report, error) {
	if !IsValidSubjectType(subjectType) {
		return Report{}, fmt.Errorf("%w: subject_type must be one of assessment", ErrInvalid)
	}
	if subjectID == "" {
		return Report{}, fmt.Errorf("%w: subject_id is required", ErrInvalid)
	}
	if skip {
		if exp != nil {
			return Report{}, fmt.Errorf("%w: experience must be omitted when skipping", ErrInvalid)
		}
	} else {
		if exp == nil {
			return Report{}, fmt.Errorf("%w: experience is required unless skip is true", ErrInvalid)
		}
		if !IsValidExperience(*exp) {
			return Report{}, fmt.Errorf("%w: experience must be one of smooth, issue, complaint", ErrInvalid)
		}
	}
	return s.repo.Upsert(ctx, orgID, subjectType, subjectID, userID, exp, description, skip)
}

// GetMine returns the authenticated user's existing experience report for a
// subject, validating the subject type before querying.
func (s *Service) GetMine(ctx context.Context, subjectType SubjectType, subjectID, userID string) (Report, error) {
	if !IsValidSubjectType(subjectType) {
		return Report{}, fmt.Errorf("%w: subject_type must be one of assessment", ErrInvalid)
	}
	return s.repo.GetMine(ctx, subjectType, subjectID, userID)
}
