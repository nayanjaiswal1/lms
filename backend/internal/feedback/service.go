package feedback

import (
	"context"
	"errors"
	"fmt"
)

// ErrInvalid signals a request that failed validation before reaching the
// database (unknown subject type, missing rating, out-of-range rating).
var ErrInvalid = errors.New("feedback: invalid input")

// ErrForbidden signals the caller isn't eligible to rate this subject (only
// enforced for subject_type=mentor today — see MentorshipVerifier).
var ErrForbidden = errors.New("feedback: forbidden")

// MentorshipVerifier is the narrow capability feedback needs from the
// mentoring package to gate mentor ratings: a student may only rate a mentor
// who has actually been assigned to them at some point. Declared here
// (rather than importing mentoring directly) so feedback stays a leaf
// dependency — mentoring.Service satisfies this interface structurally.
type MentorshipVerifier interface {
	HasBeenMentoredBy(ctx context.Context, orgID, studentID, mentorID string) (bool, error)
}

type Service struct {
	repo       *Repo
	mentorship MentorshipVerifier
}

func NewService(repo *Repo, mentorship MentorshipVerifier) *Service {
	return &Service{repo: repo, mentorship: mentorship}
}

// Submit validates and persists userID's feedback for a subject: exactly one
// answer for its kind (a 1-5 rating, or an experience value) unless skipped,
// in which case no answer. Rating a mentor additionally requires that mentor
// to have actually mentored userID.
func (s *Service) Submit(ctx context.Context, orgID *string, userID string, req SubmitRequest) (Feedback, error) {
	if req.Kind == "" {
		req.Kind = KindRating
	}
	if !IsValidSubjectType(req.SubjectType) {
		return Feedback{}, fmt.Errorf("%w: subject_type must be one of course, assessment, lab, mentor, mentor_session", ErrInvalid)
	}
	if !IsValidKind(req.Kind) {
		return Feedback{}, fmt.Errorf("%w: kind must be one of rating, experience", ErrInvalid)
	}
	if req.SubjectID == "" {
		return Feedback{}, fmt.Errorf("%w: subject_id is required", ErrInvalid)
	}
	if err := validateAnswer(req); err != nil {
		return Feedback{}, err
	}
	if req.SubjectType == SubjectTypeMentor && req.Kind == KindRating {
		if orgID == nil {
			return Feedback{}, fmt.Errorf("%w: org_id is required for mentor feedback", ErrInvalid)
		}
		mentored, err := s.mentorship.HasBeenMentoredBy(ctx, *orgID, userID, req.SubjectID)
		if err != nil {
			return Feedback{}, fmt.Errorf("feedback: verify mentorship: %w", err)
		}
		if !mentored {
			return Feedback{}, fmt.Errorf("%w: you can only rate a mentor who has mentored you", ErrForbidden)
		}
	}
	return s.repo.Upsert(ctx, orgID, userID, req)
}

// validateAnswer enforces one answer matching the kind, or none when skipping.
func validateAnswer(req SubmitRequest) error {
	if req.Kind == KindRating && req.Experience != nil {
		return fmt.Errorf("%w: experience is only for kind experience", ErrInvalid)
	}
	if req.Kind == KindExperience && req.Rating != nil {
		return fmt.Errorf("%w: rating is only for kind rating", ErrInvalid)
	}
	if req.Skip {
		if req.Rating != nil || req.Experience != nil {
			return fmt.Errorf("%w: omit the answer when skipping", ErrInvalid)
		}
		return nil
	}
	if req.Kind == KindExperience {
		if req.Experience == nil {
			return fmt.Errorf("%w: experience is required unless skip is true", ErrInvalid)
		}
		if _, ok := validExperiences[*req.Experience]; !ok {
			return fmt.Errorf("%w: experience must be one of smooth, issue, complaint", ErrInvalid)
		}
		return nil
	}
	if req.Rating == nil {
		return fmt.Errorf("%w: rating is required unless skip is true", ErrInvalid)
	}
	if *req.Rating < 1 || *req.Rating > 5 {
		return fmt.Errorf("%w: rating must be between 1 and 5", ErrInvalid)
	}
	return nil
}

// GetMine returns userID's own feedback of one kind for a subject.
func (s *Service) GetMine(ctx context.Context, kind Kind, subjectType SubjectType, subjectID, userID string) (Feedback, error) {
	if !IsValidSubjectType(subjectType) {
		return Feedback{}, fmt.Errorf("%w: subject_type must be one of course, assessment, lab, mentor, mentor_session", ErrInvalid)
	}
	if !IsValidKind(kind) {
		return Feedback{}, fmt.Errorf("%w: kind must be one of rating, experience", ErrInvalid)
	}
	return s.repo.GetMine(ctx, kind, subjectType, subjectID, userID)
}

// defaultReviewLimit/maxReviewLimit bound the ?limit= query param on
// ListPublic — a caller passing 0 or omitting it gets the default; anything
// above the max is clamped rather than rejected, since there's no harm in a
// caller asking for "too many" reviews.
const (
	defaultReviewLimit = 10
	maxReviewLimit     = 50
)

// ListPublic returns the most recent written reviews for a subject, visible
// to any authenticated org member (same no-extra-gate policy as Submit/GetMine).
func (s *Service) ListPublic(ctx context.Context, orgID *string, subjectType SubjectType, subjectID string, limit int) ([]PublicReview, error) {
	if !IsValidSubjectType(subjectType) {
		return nil, fmt.Errorf("%w: subject_type must be one of course, assessment, lab, mentor, mentor_session", ErrInvalid)
	}
	if limit <= 0 {
		limit = defaultReviewLimit
	} else if limit > maxReviewLimit {
		limit = maxReviewLimit
	}
	return s.repo.ListPublic(ctx, orgID, subjectType, subjectID, limit)
}
