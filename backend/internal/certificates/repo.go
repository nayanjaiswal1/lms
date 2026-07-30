package certificates

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound         = errors.New("certificates: not found")
	ErrAlreadyCertified = errors.New("certificates: certificate already issued for this course")
)

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// ─── Final tests ──────────────────────────────────────────────────────────────

func (r *Repo) GetFinalTestByCourse(ctx context.Context, courseID string) (FinalTest, error) {
	var ft FinalTest
	var raw []byte
	err := r.pool.QueryRow(ctx,
		`SELECT id, course_id, questions, time_limit_minutes, passing_score_percent, max_attempts, created_at, updated_at
		 FROM final_tests WHERE course_id = $1`, courseID,
	).Scan(&ft.ID, &ft.CourseID, &raw, &ft.TimeLimitMinutes, &ft.PassingScorePercent, &ft.MaxAttempts, &ft.CreatedAt, &ft.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return FinalTest{}, ErrNotFound
		}
		return FinalTest{}, fmt.Errorf("certificates: get final test: %w", err)
	}
	if err := json.Unmarshal(raw, &ft.Questions); err != nil {
		return FinalTest{}, fmt.Errorf("certificates: unmarshal questions: %w", err)
	}
	return ft, nil
}

// UpsertFinalTest creates or replaces the one final test a course may have.
func (r *Repo) UpsertFinalTest(ctx context.Context, courseID, orgID string, req UpsertFinalTestRequest) (FinalTest, error) {
	raw, err := json.Marshal(req.Questions)
	if err != nil {
		return FinalTest{}, fmt.Errorf("certificates: marshal questions: %w", err)
	}
	var ft FinalTest
	var rawOut []byte
	err = r.pool.QueryRow(ctx,
		`INSERT INTO final_tests (course_id, org_id, questions, time_limit_minutes, passing_score_percent, max_attempts)
		 VALUES ($1, $2, $3, $4, $5, $6)
		 ON CONFLICT (course_id) DO UPDATE
		   SET questions = EXCLUDED.questions,
		       time_limit_minutes = EXCLUDED.time_limit_minutes,
		       passing_score_percent = EXCLUDED.passing_score_percent,
		       max_attempts = EXCLUDED.max_attempts,
		       updated_at = now()
		 RETURNING id, course_id, questions, time_limit_minutes, passing_score_percent, max_attempts, created_at, updated_at`,
		courseID, orgID, raw, req.TimeLimitMinutes, req.PassingScorePercent, req.MaxAttempts,
	).Scan(&ft.ID, &ft.CourseID, &rawOut, &ft.TimeLimitMinutes, &ft.PassingScorePercent, &ft.MaxAttempts, &ft.CreatedAt, &ft.UpdatedAt)
	if err != nil {
		return FinalTest{}, fmt.Errorf("certificates: upsert final test: %w", err)
	}
	if err := json.Unmarshal(rawOut, &ft.Questions); err != nil {
		return FinalTest{}, fmt.Errorf("certificates: unmarshal questions: %w", err)
	}
	return ft, nil
}

// ─── Attempts ─────────────────────────────────────────────────────────────────

func (r *Repo) CountAttempts(ctx context.Context, userID, finalTestID string) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM final_test_attempts WHERE user_id = $1 AND final_test_id = $2`,
		userID, finalTestID,
	).Scan(&n)
	if err != nil {
		return 0, fmt.Errorf("certificates: count attempts: %w", err)
	}
	return n, nil
}

func (r *Repo) HasPassedAttempt(ctx context.Context, userID, finalTestID string) (bool, error) {
	var ok bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM final_test_attempts WHERE user_id = $1 AND final_test_id = $2 AND passed)`,
		userID, finalTestID,
	).Scan(&ok)
	if err != nil {
		return false, fmt.Errorf("certificates: has passed attempt: %w", err)
	}
	return ok, nil
}

func (r *Repo) CreateAttempt(ctx context.Context, userID, finalTestID string, answers json.RawMessage, score, total int, passed bool) (Attempt, error) {
	var a Attempt
	err := r.pool.QueryRow(ctx,
		`INSERT INTO final_test_attempts (user_id, final_test_id, answers, score, total, passed)
		 VALUES ($1, $2, $3, $4, $5, $6)
		 RETURNING id, user_id, final_test_id, answers, score, total, passed, completed_at`,
		userID, finalTestID, answers, score, total, passed,
	).Scan(&a.ID, &a.UserID, &a.FinalTestID, &a.Answers, &a.Score, &a.Total, &a.Passed, &a.CompletedAt)
	if err != nil {
		return Attempt{}, fmt.Errorf("certificates: create attempt: %w", err)
	}
	return a, nil
}

// ─── Certificates ─────────────────────────────────────────────────────────────

// GetCertificateForCourse returns the learner's existing certificate for a
// course, if one was already issued (a passed learner may retake nothing —
// this is the idempotency check before issuing a second one).
func (r *Repo) GetCertificateForCourse(ctx context.Context, userID, courseID string) (Certificate, error) {
	var c Certificate
	err := r.pool.QueryRow(ctx,
		`SELECT id, user_id, course_id, final_test_attempt_id, issued_at, cert_uuid, issue_type, issued_by
		 FROM certificates WHERE user_id = $1 AND course_id = $2`,
		userID, courseID,
	).Scan(&c.ID, &c.UserID, &c.CourseID, &c.FinalTestAttemptID, &c.IssuedAt, &c.CertUUID, &c.IssueType, &c.IssuedBy)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Certificate{}, ErrNotFound
		}
		return Certificate{}, fmt.Errorf("certificates: get certificate: %w", err)
	}
	return c, nil
}

// IssueCertificate inserts a new certificate row. attemptID is set only for
// the final-test path (nil for manual/threshold); issuedBy is set only for
// the manual path (nil otherwise).
func (r *Repo) IssueCertificate(ctx context.Context, userID, courseID string, attemptID, issuedBy *string, issueType string) (Certificate, error) {
	var c Certificate
	err := r.pool.QueryRow(ctx,
		`INSERT INTO certificates (user_id, course_id, final_test_attempt_id, issue_type, issued_by)
		 VALUES ($1, $2, $3, $4, $5)
		 RETURNING id, user_id, course_id, final_test_attempt_id, issued_at, cert_uuid, issue_type, issued_by`,
		userID, courseID, attemptID, issueType, issuedBy,
	).Scan(&c.ID, &c.UserID, &c.CourseID, &c.FinalTestAttemptID, &c.IssuedAt, &c.CertUUID, &c.IssueType, &c.IssuedBy)
	if err != nil {
		return Certificate{}, fmt.Errorf("certificates: issue certificate: %w", err)
	}
	return c, nil
}

func (r *Repo) ListMyCertificates(ctx context.Context, userID string) ([]CertificateView, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT cert.id, cert.user_id, cert.course_id, cert.final_test_attempt_id, cert.issued_at, cert.cert_uuid,
		        cert.issue_type, cert.issued_by, c.title, u.name
		 FROM certificates cert
		 JOIN courses c ON c.id = cert.course_id
		 JOIN users u ON u.id = cert.user_id
		 WHERE cert.user_id = $1
		 ORDER BY cert.issued_at DESC`, userID)
	if err != nil {
		return nil, fmt.Errorf("certificates: list my certificates: %w", err)
	}
	defer rows.Close()

	out := []CertificateView{}
	for rows.Next() {
		var v CertificateView
		if err := rows.Scan(&v.ID, &v.UserID, &v.CourseID, &v.FinalTestAttemptID, &v.IssuedAt, &v.CertUUID,
			&v.IssueType, &v.IssuedBy, &v.CourseTitle, &v.LearnerName); err != nil {
			return nil, fmt.Errorf("certificates: scan certificate view: %w", err)
		}
		out = append(out, v)
	}
	return out, rows.Err()
}

// GetByUUID is the public, no-auth verification lookup.
func (r *Repo) GetByUUID(ctx context.Context, certUUID string) (CertificateView, error) {
	var v CertificateView
	err := r.pool.QueryRow(ctx,
		`SELECT cert.id, cert.user_id, cert.course_id, cert.final_test_attempt_id, cert.issued_at, cert.cert_uuid,
		        cert.issue_type, cert.issued_by, c.title, u.name
		 FROM certificates cert
		 JOIN courses c ON c.id = cert.course_id
		 JOIN users u ON u.id = cert.user_id
		 WHERE cert.cert_uuid = $1`, certUUID,
	).Scan(&v.ID, &v.UserID, &v.CourseID, &v.FinalTestAttemptID, &v.IssuedAt, &v.CertUUID,
		&v.IssueType, &v.IssuedBy, &v.CourseTitle, &v.LearnerName)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return CertificateView{}, ErrNotFound
		}
		return CertificateView{}, fmt.Errorf("certificates: get by uuid: %w", err)
	}
	return v, nil
}

// ─── Certificate rules (threshold-based auto-issue config) ────────────────────

// UpsertCertificateRule creates or replaces the one threshold rule a course
// may have.
func (r *Repo) UpsertCertificateRule(ctx context.Context, courseID string, thresholdPercent int) (CertificateRule, error) {
	var rule CertificateRule
	err := r.pool.QueryRow(ctx,
		`INSERT INTO certificate_rules (course_id, threshold_percent)
		 VALUES ($1, $2)
		 ON CONFLICT (course_id) DO UPDATE
		   SET threshold_percent = EXCLUDED.threshold_percent, updated_at = now()
		 RETURNING id, course_id, threshold_percent, created_at, updated_at`,
		courseID, thresholdPercent,
	).Scan(&rule.ID, &rule.CourseID, &rule.ThresholdPercent, &rule.CreatedAt, &rule.UpdatedAt)
	if err != nil {
		return CertificateRule{}, fmt.Errorf("certificates: upsert certificate rule: %w", err)
	}
	return rule, nil
}

func (r *Repo) GetCertificateRule(ctx context.Context, courseID string) (CertificateRule, error) {
	var rule CertificateRule
	err := r.pool.QueryRow(ctx,
		`SELECT id, course_id, threshold_percent, created_at, updated_at
		 FROM certificate_rules WHERE course_id = $1`, courseID,
	).Scan(&rule.ID, &rule.CourseID, &rule.ThresholdPercent, &rule.CreatedAt, &rule.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return CertificateRule{}, ErrNotFound
		}
		return CertificateRule{}, fmt.Errorf("certificates: get certificate rule: %w", err)
	}
	return rule, nil
}
