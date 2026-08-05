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
	// Anonymous attempt: user_id is NULL, anonymous_identity holds name/email/phone as jsonb
	anonIdentity := map[string]interface{}{
		"name":  name,
		"email": email,
	}
	if phone != nil {
		anonIdentity["phone"] = *phone
	}
	anonJSON, _ := json.Marshal(anonIdentity)

	err := r.pool.QueryRow(ctx,
		`INSERT INTO assessment_attempts (assessment_id, user_id, anonymous_identity, status, started_at, active_session_token)
		 VALUES ($1, NULL, $2, 'in_progress', now(), gen_random_uuid()::text)
		 RETURNING id, active_session_token, started_at`,
		assessmentID, anonJSON,
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
	var anonID []byte
	err := r.pool.QueryRow(ctx,
		`SELECT id, assessment_id, anonymous_identity, active_session_token,
		        answers, score, max_score, percentage, passed,
		        flags, status, started_at, submitted_at, duration_sec
		 FROM assessment_attempts
		 WHERE active_session_token = $1 AND user_id IS NULL`, token,
	).Scan(
		&att.ID, &att.AssessmentID, &anonID, &att.SessionToken,
		&answers, &att.Score, &att.MaxScore, &att.Percentage, &att.Passed,
		&att.Flags, &att.Status, &att.StartedAt, &att.SubmittedAt, &att.DurationSec,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return PublicAttempt{}, ErrNotFound
		}
		return PublicAttempt{}, fmt.Errorf("assessment: get public attempt: %w", err)
	}
	// Extract name, email, phone from anonymous_identity jsonb
	if len(anonID) > 0 {
		var anonData map[string]interface{}
		if err := json.Unmarshal(anonID, &anonData); err == nil {
			if v, ok := anonData["name"]; ok {
				att.Name = v.(string)
			}
			if v, ok := anonData["email"]; ok {
				att.Email = v.(string)
			}
			if v, ok := anonData["phone"]; ok {
				phone := v.(string)
				att.Phone = &phone
			}
		}
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
		`UPDATE assessment_attempts
		 SET answers = $2, score = $3, max_score = $4, percentage = $5,
		     passed = $6, status = 'submitted', submitted_at = now(), duration_sec = $7
		 WHERE active_session_token = $1 AND status = 'in_progress' AND user_id IS NULL`,
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
		`SELECT a.pass_percentage, aa.max_score
		 FROM assessment_attempts aa JOIN assessments a ON a.id = aa.assessment_id
		 WHERE aa.id = $1 AND a.org_id = $2 AND aa.user_id IS NULL`,
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
		`UPDATE assessment_attempts
		 SET score = $2, percentage = $3, passed = $4,
		     override_note = $5, overridden_by = $6, overridden_at = now()
		 WHERE id = $1 AND user_id IS NULL`,
		publicAttemptID, score, pct, passed, note, reviewerID)
	if err != nil {
		return PublicAttempt{}, fmt.Errorf("assessment: override public attempt score: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return PublicAttempt{}, ErrNotFound
	}

	var att PublicAttempt
	var answers []byte
	var anonID []byte
	if err := r.pool.QueryRow(ctx,
		`SELECT id, assessment_id, anonymous_identity, active_session_token,
		        answers, score, max_score, percentage, passed,
		        flags, status, started_at, submitted_at, duration_sec
		 FROM assessment_attempts WHERE id = $1 AND user_id IS NULL`, publicAttemptID,
	).Scan(
		&att.ID, &att.AssessmentID, &anonID, &att.SessionToken,
		&answers, &att.Score, &att.MaxScore, &att.Percentage, &att.Passed,
		&att.Flags, &att.Status, &att.StartedAt, &att.SubmittedAt, &att.DurationSec,
	); err != nil {
		return PublicAttempt{}, fmt.Errorf("assessment: reload overridden public attempt: %w", err)
	}
	// Extract name, email, phone from anonymous_identity jsonb
	if len(anonID) > 0 {
		var anonData map[string]interface{}
		if err := json.Unmarshal(anonID, &anonData); err == nil {
			if v, ok := anonData["name"]; ok {
				att.Name = v.(string)
			}
			if v, ok := anonData["email"]; ok {
				att.Email = v.(string)
			}
			if v, ok := anonData["phone"]; ok {
				phone := v.(string)
				att.Phone = &phone
			}
		}
	}
	if len(answers) > 0 {
		att.Answers = answers
	}
	return att, nil
}

// ListPublicAttempts returns all candidate attempts for an assessment (staff view).
func (r *Repo) ListPublicAttempts(ctx context.Context, assessmentID string) ([]PublicAttempt, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, assessment_id, anonymous_identity, active_session_token,
		        score, max_score, percentage, passed, flags, status,
		        started_at, submitted_at, duration_sec
		 FROM assessment_attempts
		 WHERE assessment_id = $1 AND user_id IS NULL
		 ORDER BY started_at DESC`, assessmentID)
	if err != nil {
		return nil, fmt.Errorf("assessment: list public attempts: %w", err)
	}
	defer rows.Close()

	var out []PublicAttempt
	for rows.Next() {
		var att PublicAttempt
		var anonID []byte
		if err := rows.Scan(
			&att.ID, &att.AssessmentID, &anonID, &att.SessionToken,
			&att.Score, &att.MaxScore, &att.Percentage, &att.Passed,
			&att.Flags, &att.Status, &att.StartedAt, &att.SubmittedAt, &att.DurationSec,
		); err != nil {
			return nil, fmt.Errorf("assessment: scan public attempt: %w", err)
		}
		// Extract name, email, phone from anonymous_identity jsonb
		if len(anonID) > 0 {
			var anonData map[string]interface{}
			if err := json.Unmarshal(anonID, &anonData); err == nil {
				if v, ok := anonData["name"]; ok {
					att.Name = v.(string)
				}
				if v, ok := anonData["email"]; ok {
					att.Email = v.(string)
				}
				if v, ok := anonData["phone"]; ok {
					phone := v.(string)
					att.Phone = &phone
				}
			}
		}
		out = append(out, att)
	}
	return out, rows.Err()
}
