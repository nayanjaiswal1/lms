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
// freshly generated test_id, in a transaction so the submission is all-or-nothing.
func (r *Repo) CreateOfflineTestScores(
	ctx context.Context, orgID, batchID, testName string, testDate time.Time,
	maxScore float64, enteredBy string, entries []OfflineTestScoreEntry,
) (string, error) {
	if len(entries) == 0 {
		return "", fmt.Errorf("assessment: create offline test scores: no entries")
	}
	testID := uuid.NewString()

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

		userIDs := make([]string, len(entries))
		scores := make([]float64, len(entries))
		for i, e := range entries {
			userIDs[i] = e.UserID
			scores[i] = e.Score
		}

		if _, err := tx.Exec(ctx,
			`INSERT INTO offline_test_scores
			   (org_id, batch_id, user_id, test_id, test_name, test_date, max_score, score, entered_by)
			 SELECT $1, $2, x.user_id, $3, $4, $5, $6, x.score, $7
			 FROM unnest($8::uuid[], $9::numeric[]) AS x(user_id, score)`,
			orgID, batchID, testID, testName, testDate, maxScore, enteredBy, userIDs, scores); err != nil {
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
	return testID, nil
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

// ListOfflineTests returns one summary row per test_id entered for the batch.
func (r *Repo) ListOfflineTests(ctx context.Context, orgID, batchID string) ([]OfflineTestSummary, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT ots.test_id, ots.test_name, ots.test_date, ots.max_score,
		        COUNT(*), AVG(ots.score)
		 FROM offline_test_scores ots
		 WHERE ots.batch_id = $1
		   AND EXISTS (SELECT 1 FROM batches b WHERE b.id = $1 AND b.org_id = $2)
		 GROUP BY ots.test_id, ots.test_name, ots.test_date, ots.max_score
		 ORDER BY ots.test_date DESC`, batchID, orgID)
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
		`SELECT ots.test_id, ots.test_name, ots.test_date, ots.max_score,
		        u.id, u.name, u.email, ots.score
		 FROM offline_test_scores ots
		 JOIN users u ON u.id = ots.user_id
		 WHERE ots.batch_id = $1 AND ots.test_id = $2
		   AND EXISTS (SELECT 1 FROM batches b WHERE b.id = $1 AND b.org_id = $3)
		 ORDER BY u.name`, batchID, testID, orgID)
	if err != nil {
		return out, fmt.Errorf("assessment: get offline test scores: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var row OfflineTestScoreRow
		if err := rows.Scan(&out.TestID, &out.TestName, &out.TestDate, &out.MaxScore,
			&row.UserID, &row.UserName, &row.Email, &row.Score); err != nil {
			return out, fmt.Errorf("assessment: scan offline test score: %w", err)
		}
		out.Scores = append(out.Scores, row)
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
		`UPDATE offline_test_scores SET score = $1, updated_at = now()
		 WHERE batch_id = $2 AND test_id = $3 AND user_id = $4
		   AND EXISTS (SELECT 1 FROM batches b WHERE b.id = $2 AND b.org_id = $5)`,
		score, batchID, testID, userID, orgID)
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
