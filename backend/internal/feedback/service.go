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

// Submit validates and persists a learner's feedback for a subject. Exactly
// one of (rating, skip) must be set: a real submission requires a 1-5
// rating; a skip requires no rating. comment is always optional. Rating a
// mentor additionally requires that mentor to have actually mentored userID.
func (s *Service) Submit(ctx context.Context, orgID string, subjectType SubjectType, subjectID, userID string, rating *int, comment *string, skip bool) (Feedback, error) {
	if !IsValidSubjectType(subjectType) {
		return Feedback{}, fmt.Errorf("%w: subject_type must be one of course, assessment, lab, mentor", ErrInvalid)
	}
	if subjectID == "" {
		return Feedback{}, fmt.Errorf("%w: subject_id is required", ErrInvalid)
	}
	if subjectType == SubjectTypeMentor {
		mentored, err := s.mentorship.HasBeenMentoredBy(ctx, orgID, userID, subjectID)
		if err != nil {
			return Feedback{}, fmt.Errorf("feedback: verify mentorship: %w", err)
		}
		if !mentored {
			return Feedback{}, fmt.Errorf("%w: you can only rate a mentor who has mentored you", ErrForbidden)
		}
	}
	if skip {
		if rating != nil {
			return Feedback{}, fmt.Errorf("%w: rating must be omitted when skipping", ErrInvalid)
		}
	} else {
		if rating == nil {
			return Feedback{}, fmt.Errorf("%w: rating is required unless skip is true", ErrInvalid)
		}
		if *rating < 1 || *rating > 5 {
			return Feedback{}, fmt.Errorf("%w: rating must be between 1 and 5", ErrInvalid)
		}
	}
	return s.repo.Upsert(ctx, orgID, subjectType, subjectID, userID, rating, comment, skip)
}

// GetMine returns the authenticated user's existing feedback for a subject,
// validating the subject type before querying.
func (s *Service) GetMine(ctx context.Context, subjectType SubjectType, subjectID, userID string) (Feedback, error) {
	if !IsValidSubjectType(subjectType) {
		return Feedback{}, fmt.Errorf("%w: subject_type must be one of course, assessment, lab, mentor", ErrInvalid)
	}
	return s.repo.GetMine(ctx, subjectType, subjectID, userID)
}
