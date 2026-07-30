package assessment

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

// PublicAttempt is a candidate's anonymous test session for a hiring assessment.
type PublicAttempt struct {
	ID           string          `json:"id"`
	AssessmentID string          `json:"assessment_id"`
	Name         string          `json:"name"`
	Email        string          `json:"email"`
	Phone        *string         `json:"phone,omitempty"`
	SessionToken string          `json:"session_token"`
	Answers      json.RawMessage `json:"answers,omitempty"`
	Score        *float64        `json:"score,omitempty"`
	MaxScore     *float64        `json:"max_score,omitempty"`
	Percentage   *float64        `json:"percentage,omitempty"`
	Passed       *bool           `json:"passed,omitempty"`
	Flags        int             `json:"flags"`
	Status       string          `json:"status"`
	StartedAt    time.Time       `json:"started_at"`
	SubmittedAt  *time.Time      `json:"submitted_at,omitempty"`
	DurationSec  *int            `json:"duration_sec,omitempty"`
}

func (r *Repo) GetAssessmentByShortCode(ctx context.Context, code string) (Assessment, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT a.id, a.org_id, a.title, a.slug, a.description, a.type, a.status,
		        a.parent_type, a.parent_id, a.duration_minutes, a.pass_percentage,
		        a.max_attempts, a.total_points, a.mock_mode, a.shuffle_questions, a.shuffle_options,
		        a.allow_backtrack, a.show_results, a.starts_at, a.ends_at, a.proctoring,
		        a.created_by, a.published_at, a.created_at, a.updated_at,
		        (SELECT count(*) FROM assessment_questions aq WHERE aq.assessment_id = a.id),
		        a.short_code, NULL::uuid, NULL::text
		 FROM assessments a
		 WHERE a.short_code = $1 AND a.status = 'published'`, code)
	return scanAssessment(row)
}

func (r *Repo) CreatePublicAttempt(ctx context.Context, assessmentID, name, email string, phone *string) (PublicAttempt, error) {
	var att PublicAttempt
	err := r.pool.QueryRow(ctx,
		`INSERT INTO public_attempts (assessment_id, name, email, phone)
		 VALUES ($1, $2, $3, $4)
		 RETURNING id, session_token, started_at`,
		assessmentID, name, email, phone,
	).Scan(&att.ID, &att.SessionToken, &att.StartedAt)
	if err != nil {
		return PublicAttempt{}, fmt.Errorf("assessment: create public attempt: %w", err)
	}
	att.AssessmentID = assessmentID
	att.Name = name
	att.Email = email
	att.Phone = phone
	att.Status = "in_progress"
	return att, nil
}

func (r *Repo) GetPublicAttemptByToken(ctx context.Context, token string) (PublicAttempt, error) {
	var att PublicAttempt
	var answers []byte
	err := r.pool.QueryRow(ctx,
		`SELECT id, assessment_id, name, email, phone, session_token,
		        answers, score, max_score, percentage, passed,
		        flags, status, started_at, submitted_at, duration_sec
		 FROM public_attempts
		 WHERE session_token = $1`, token,
	).Scan(
		&att.ID, &att.AssessmentID, &att.Name, &att.Email, &att.Phone, &att.SessionToken,
		&answers, &att.Score, &att.MaxScore, &att.Percentage, &att.Passed,
		&att.Flags, &att.Status, &att.StartedAt, &att.SubmittedAt, &att.DurationSec,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return PublicAttempt{}, ErrNotFound
		}
		return PublicAttempt{}, fmt.Errorf("assessment: get public attempt: %w", err)
	}
	if len(answers) > 0 {
		att.Answers = answers
	}
	return att, nil
}

// FinalizePublicAttempt persists an already-graded candidate result. Grading
// itself (MCQ + coding, the latter needing the executor the repo layer has no
// access to) happens in Service.SubmitPublicAttempt — this only writes the
// outcome, mirroring how FinalizeAttempt is the persistence tail of the
// authenticated finalizeSubmit.
func (r *Repo) FinalizePublicAttempt(ctx context.Context, token string, answersRaw json.RawMessage, totalScore, maxScore, pct float64, passed bool, durationSec int) (PublicAttempt, error) {
	att, err := r.GetPublicAttemptByToken(ctx, token)
	if err != nil {
		return PublicAttempt{}, err
	}
	if att.Status == "submitted" {
		return att, nil
	}

	_, err = r.pool.Exec(ctx,
		`UPDATE public_attempts
		 SET answers = $2, score = $3, max_score = $4, percentage = $5,
		     passed = $6, status = 'submitted', submitted_at = now(), duration_sec = $7
		 WHERE session_token = $1 AND status = 'in_progress'`,
		token, answersRaw, totalScore, maxScore, pct, passed, durationSec,
	)
	if err != nil {
		return PublicAttempt{}, fmt.Errorf("assessment: submit public attempt: %w", err)
	}

	att.Score = &totalScore
	att.MaxScore = &maxScore
	att.Percentage = &pct
	att.Passed = &passed
	att.Status = "submitted"
	att.DurationSec = &durationSec
	att.Answers = answersRaw
	return att, nil
}

// OverridePublicAttemptScore lets staff manually adjust a hiring candidate's
// total score. public_attempts has no per-question breakdown (see
// PublicAttempt) so, unlike OverrideAnswerScore, this replaces the aggregate
// score/percentage/passed directly rather than recomputing from a sum.
// orgID scopes the update through assessments so staff can only override
// candidates within their own org.
func (r *Repo) OverridePublicAttemptScore(ctx context.Context, orgID, publicAttemptID, reviewerID string, score float64, note string) (PublicAttempt, error) {
	var passPercent, maxScore float64
	if err := r.pool.QueryRow(ctx,
		`SELECT a.pass_percentage, pa.max_score
		 FROM public_attempts pa JOIN assessments a ON a.id = pa.assessment_id
		 WHERE pa.id = $1 AND a.org_id = $2`,
		publicAttemptID, orgID).Scan(&passPercent, &maxScore); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return PublicAttempt{}, ErrNotFound
		}
		return PublicAttempt{}, fmt.Errorf("assessment: load public attempt for override: %w", err)
	}

	var pct float64
	if maxScore > 0 {
		pct = (score / maxScore) * 100
	}
	passed := pct >= passPercent

	tag, err := r.pool.Exec(ctx,
		`UPDATE public_attempts
		 SET score = $2, percentage = $3, passed = $4,
		     override_note = $5, overridden_by = $6, overridden_at = now()
		 WHERE id = $1`,
		publicAttemptID, score, pct, passed, note, reviewerID)
	if err != nil {
		return PublicAttempt{}, fmt.Errorf("assessment: override public attempt score: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return PublicAttempt{}, ErrNotFound
	}

	var att PublicAttempt
	var answers []byte
	if err := r.pool.QueryRow(ctx,
		`SELECT id, assessment_id, name, email, phone, session_token,
		        answers, score, max_score, percentage, passed,
		        flags, status, started_at, submitted_at, duration_sec
		 FROM public_attempts WHERE id = $1`, publicAttemptID,
	).Scan(
		&att.ID, &att.AssessmentID, &att.Name, &att.Email, &att.Phone, &att.SessionToken,
		&answers, &att.Score, &att.MaxScore, &att.Percentage, &att.Passed,
		&att.Flags, &att.Status, &att.StartedAt, &att.SubmittedAt, &att.DurationSec,
	); err != nil {
		return PublicAttempt{}, fmt.Errorf("assessment: reload overridden public attempt: %w", err)
	}
	if len(answers) > 0 {
		att.Answers = answers
	}
	return att, nil
}

// ListPublicAttempts returns all candidate attempts for an assessment (staff view).
func (r *Repo) ListPublicAttempts(ctx context.Context, assessmentID string) ([]PublicAttempt, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, assessment_id, name, email, phone, session_token,
		        score, max_score, percentage, passed, flags, status,
		        started_at, submitted_at, duration_sec
		 FROM public_attempts
		 WHERE assessment_id = $1
		 ORDER BY started_at DESC`, assessmentID)
	if err != nil {
		return nil, fmt.Errorf("assessment: list public attempts: %w", err)
	}
	defer rows.Close()

	var out []PublicAttempt
	for rows.Next() {
		var att PublicAttempt
		if err := rows.Scan(
			&att.ID, &att.AssessmentID, &att.Name, &att.Email, &att.Phone, &att.SessionToken,
			&att.Score, &att.MaxScore, &att.Percentage, &att.Passed,
			&att.Flags, &att.Status, &att.StartedAt, &att.SubmittedAt, &att.DurationSec,
		); err != nil {
			return nil, fmt.Errorf("assessment: scan public attempt: %w", err)
		}
		out = append(out, att)
	}
	return out, rows.Err()
}
