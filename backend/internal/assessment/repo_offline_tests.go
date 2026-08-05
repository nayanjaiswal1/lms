package assessment

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

// ─────────────────────────────────────────────
// Classroom Test Assessment Engine — manual entry for offline/paper tests.
// A "test" is a name + date, not a reusable catalog entity: every score row
// entered in one "Enter Scores" submission shares a generated test_id so the
// set is addressable for viewing/editing later.
// ponytail: no test-template table — add one if teachers need to reuse a
// test name/rubric across batches; not needed for a single class's scores.
// ─────────────────────────────────────────────

// OfflineTestScoreEntry is one student's score within a single "Enter
// Scores" submission.
type OfflineTestScoreEntry struct {
	UserID string
	Score  float64
}

// CreateOfflineTestScores inserts one score row per entry, all sharing a
// freshly generated assessment_id (an offline assessment), in a transaction so the submission is all-or-nothing.
func (r *Repo) CreateOfflineTestScores(
	ctx context.Context, orgID, batchID, testName string, testDate time.Time,
	maxScore float64, enteredBy string, entries []OfflineTestScoreEntry,
) (string, error) {
	if len(entries) == 0 {
		return "", fmt.Errorf("assessment: create offline test scores: no entries")
	}
	assessmentID := uuid.NewString()

	err := r.tx(ctx, func(tx pgx.Tx) error {
		var exists bool
		if err := tx.QueryRow(ctx,
			`SELECT EXISTS(SELECT 1 FROM batches WHERE id = $1 AND org_id = $2)`,
			batchID, orgID).Scan(&exists); err != nil {
			return fmt.Errorf("assessment: verify batch: %w", err)
		}
		if !exists {
			return ErrNotFound
		}

		// Find or create an offline assessment for this batch+testName
		var aID string
		err := tx.QueryRow(ctx,
			`SELECT id FROM assessments
			 WHERE org_id = $1 AND parent_type = 'batch' AND parent_id = $2
			   AND type = 'offline' AND title = $3
			 LIMIT 1`,
			orgID, batchID, testName).Scan(&aID)
		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("assessment: lookup offline assessment: %w", err)
		}
		if errors.Is(err, pgx.ErrNoRows) {
			// Create a new offline assessment
			err = tx.QueryRow(ctx,
				`INSERT INTO assessments (id, org_id, title, type, status, parent_type, parent_id, created_by, published_at, total_points)
				 VALUES ($1, $2, $3, 'offline', 'published', 'batch', $4, $5, now(), $6)
				 RETURNING id`,
				assessmentID, orgID, testName, batchID, enteredBy, maxScore).Scan(&aID)
			if err != nil {
				return fmt.Errorf("assessment: create offline assessment: %w", err)
			}
		}
		assessmentID = aID

		userIDs := make([]string, len(entries))
		scores := make([]float64, len(entries))
		for i, e := range entries {
			userIDs[i] = e.UserID
			scores[i] = e.Score
		}

		if _, err := tx.Exec(ctx,
			`INSERT INTO assessment_attempts (assessment_id, user_id, org_id, score, max_score, status, submitted_at, created_at, updated_at)
			 SELECT $1, x.user_id, $2, x.score, $3, 'evaluated', $4::timestamp, now(), now()
			 FROM unnest($5::uuid[]) AS x(user_id)
			 JOIN (SELECT * FROM unnest($6::numeric[]) WITH ORDINALITY) AS scores(score, idx)
			   ON TRUE
			 WHERE scores.idx = x.ordinality
			 ON CONFLICT (assessment_id, user_id) DO UPDATE
			   SET score = EXCLUDED.score, updated_at = now()`,
			assessmentID, orgID, maxScore, testDate, userIDs, scores); err != nil {
			var pgErr *pgconn.PgError
			if errors.As(err, &pgErr) && pgErr.Code == "23514" {
				return ErrInvalidScore
			}
			return fmt.Errorf("assessment: insert offline test scores: %w", err)
		}
		return nil
	})
	if err != nil {
		return "", err
	}
	return assessmentID, nil
}

// OfflineTestSummary is one row in the classroom tests list view.
type OfflineTestSummary struct {
	TestID       string    `json:"test_id"`
	TestName     string    `json:"test_name"`
	TestDate     time.Time `json:"test_date"`
	MaxScore     float64   `json:"max_score"`
	StudentCount int       `json:"student_count"`
	AvgScore     float64   `json:"avg_score"`
}

// ListOfflineTests returns one summary row per offline assessment entered for the batch.
func (r *Repo) ListOfflineTests(ctx context.Context, orgID, batchID string) ([]OfflineTestSummary, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT a.id, a.title, COALESCE(MAX(aa.submitted_at), a.created_at),
		        a.total_points, COUNT(DISTINCT aa.user_id), AVG(aa.score)
		 FROM assessments a
		 LEFT JOIN assessment_attempts aa ON aa.assessment_id = a.id
		 WHERE a.org_id = $1 AND a.parent_type = 'batch' AND a.parent_id = $2 AND a.type = 'offline'
		 GROUP BY a.id, a.title, a.total_points
		 ORDER BY COALESCE(MAX(aa.submitted_at), a.created_at) DESC`, orgID, batchID)
	if err != nil {
		return nil, fmt.Errorf("assessment: list offline tests: %w", err)
	}
	defer rows.Close()

	out := []OfflineTestSummary{}
	for rows.Next() {
		var s OfflineTestSummary
		if err := rows.Scan(&s.TestID, &s.TestName, &s.TestDate, &s.MaxScore, &s.StudentCount, &s.AvgScore); err != nil {
			return nil, fmt.Errorf("assessment: scan offline test summary: %w", err)
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// OfflineTestScoreRow is one student's score within one test — the
// view/edit detail for a single test_id.
type OfflineTestScoreRow struct {
	UserID   string  `json:"user_id"`
	UserName string  `json:"user_name"`
	Email    string  `json:"email"`
	Score    float64 `json:"score"`
}

// OfflineTestDetail is one test's full metadata plus every student's score.
type OfflineTestDetail struct {
	TestID   string                `json:"test_id"`
	TestName string                `json:"test_name"`
	TestDate time.Time             `json:"test_date"`
	MaxScore float64               `json:"max_score"`
	Scores   []OfflineTestScoreRow `json:"scores"`
}

// GetOfflineTestScores returns one test's metadata and per-student scores.
func (r *Repo) GetOfflineTestScores(ctx context.Context, orgID, batchID, testID string) (OfflineTestDetail, error) {
	var out OfflineTestDetail
	rows, err := r.pool.Query(ctx,
		`SELECT a.id, a.title, COALESCE(MAX(aa.submitted_at), a.created_at), a.total_points,
		        u.id, u.name, u.email, aa.score
		 FROM assessments a
		 LEFT JOIN assessment_attempts aa ON aa.assessment_id = a.id
		 LEFT JOIN users u ON u.id = aa.user_id
		 WHERE a.id = $1 AND a.org_id = $2 AND a.parent_type = 'batch' AND a.parent_id = $3
		   AND a.type = 'offline'
		   AND EXISTS (SELECT 1 FROM batches b WHERE b.id = $3 AND b.org_id = $2)
		 ORDER BY u.name`, testID, orgID, batchID)
	if err != nil {
		return out, fmt.Errorf("assessment: get offline test scores: %w", err)
	}
	defer rows.Close()

	seen := make(map[string]bool) // track which rows we've scanned for header info
	for rows.Next() {
		var row OfflineTestScoreRow
		var userID, userName, email *string
		var score *float64
		if err := rows.Scan(&out.TestID, &out.TestName, &out.TestDate, &out.MaxScore,
			&userID, &userName, &email, &score); err != nil {
			return out, fmt.Errorf("assessment: scan offline test score: %w", err)
		}
		// Only set header fields once per test
		if !seen["header"] {
			seen["header"] = true
		}
		// Only add scores for users with attempts
		if userID != nil && userName != nil && email != nil && score != nil {
			row.UserID = *userID
			row.UserName = *userName
			row.Email = *email
			row.Score = *score
			out.Scores = append(out.Scores, row)
		}
	}
	if err := rows.Err(); err != nil {
		return out, err
	}
	if out.TestID == "" {
		return out, ErrNotFound
	}
	return out, nil
}

// UpdateOfflineTestScore edits a single student's score within a test.
// The table's CHECK constraint rejects a score outside 0..max_score.
func (r *Repo) UpdateOfflineTestScore(ctx context.Context, orgID, batchID, testID, userID string, score float64) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE assessment_attempts SET score = $1, updated_at = now()
		 WHERE assessment_id = $2 AND user_id = $3
		   AND EXISTS (
		     SELECT 1 FROM assessments a
		     WHERE a.id = $2 AND a.org_id = $4 AND a.parent_type = 'batch'
		       AND a.parent_id = $5 AND a.type = 'offline'
		   )
		   AND EXISTS (SELECT 1 FROM batches b WHERE b.id = $5 AND b.org_id = $4)`,
		score, testID, userID, orgID, batchID)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23514" {
			return ErrInvalidScore
		}
		return fmt.Errorf("assessment: update offline test score: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
