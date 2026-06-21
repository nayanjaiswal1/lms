package assessment

import (
	"context"
	"fmt"
)

// AssessmentAnalytics summarises performance across all attempts of an assessment.
type AssessmentAnalytics struct {
	AssessmentID    string             `json:"assessment_id"`
	TotalAttempts   int                `json:"total_attempts"`
	Evaluated       int                `json:"evaluated"`
	AvgPercentage   float64            `json:"avg_percentage"`
	PassRate        float64            `json:"pass_rate"`
	AvgDurationSec  float64            `json:"avg_duration_sec"`
	HighScore       float64            `json:"high_score"`
	LowScore        float64            `json:"low_score"`
	ScoreBuckets    map[string]int     `json:"score_buckets"`
	QuestionStats   []QuestionStat     `json:"question_stats"`
	FlaggedAttempts int                `json:"flagged_attempts"`
}

// QuestionStat is the correctness rate for one question in an assessment.
type QuestionStat struct {
	QuestionID  string  `json:"question_id"`
	Title       string  `json:"title"`
	Type        string  `json:"type"`
	Answered    int     `json:"answered"`
	CorrectRate float64 `json:"correct_rate"`
	AvgPoints   float64 `json:"avg_points"`
}

// AssessmentAnalytics computes aggregate stats for one assessment within the org.
func (r *Repo) AssessmentAnalytics(ctx context.Context, orgID, assessmentID string) (AssessmentAnalytics, error) {
	out := AssessmentAnalytics{AssessmentID: assessmentID, ScoreBuckets: map[string]int{}}

	// Guard org ownership.
	var owns bool
	if err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM assessments WHERE id = $1 AND org_id = $2)`,
		assessmentID, orgID).Scan(&owns); err != nil {
		return out, fmt.Errorf("assessment: analytics ownership: %w", err)
	}
	if !owns {
		return out, ErrNotFound
	}

	err := r.pool.QueryRow(ctx,
		`SELECT
		   count(*),
		   count(*) FILTER (WHERE status = 'evaluated'),
		   COALESCE(avg(percentage) FILTER (WHERE status = 'evaluated'), 0),
		   COALESCE(avg(CASE WHEN passed THEN 1.0 ELSE 0.0 END) FILTER (WHERE status = 'evaluated') * 100, 0),
		   COALESCE(avg(duration_seconds) FILTER (WHERE status = 'evaluated'), 0),
		   COALESCE(max(percentage) FILTER (WHERE status = 'evaluated'), 0),
		   COALESCE(min(percentage) FILTER (WHERE status = 'evaluated'), 0)
		 FROM assessment_attempts
		 WHERE assessment_id = $1 AND status IN ('submitted','evaluated','expired')`,
		assessmentID).Scan(&out.TotalAttempts, &out.Evaluated, &out.AvgPercentage,
		&out.PassRate, &out.AvgDurationSec, &out.HighScore, &out.LowScore)
	if err != nil {
		return out, fmt.Errorf("assessment: analytics aggregate: %w", err)
	}

	// Score distribution buckets (0-20 … 80-100).
	bucketRows, err := r.pool.Query(ctx,
		`SELECT width_bucket(percentage, 0, 100, 5) AS b, count(*)
		 FROM assessment_attempts
		 WHERE assessment_id = $1 AND status = 'evaluated' AND percentage IS NOT NULL
		 GROUP BY b ORDER BY b`, assessmentID)
	if err != nil {
		return out, fmt.Errorf("assessment: analytics buckets: %w", err)
	}
	labels := map[int]string{1: "0-20", 2: "20-40", 3: "40-60", 4: "60-80", 5: "80-100", 6: "80-100"}
	for bucketRows.Next() {
		var b, n int
		if err := bucketRows.Scan(&b, &n); err != nil {
			bucketRows.Close()
			return out, fmt.Errorf("assessment: scan bucket: %w", err)
		}
		out.ScoreBuckets[labels[b]] += n
	}
	bucketRows.Close()
	if err := bucketRows.Err(); err != nil {
		return out, err
	}

	// Per-question correctness.
	qRows, err := r.pool.Query(ctx,
		`SELECT q.id, q.title, q.type,
		        count(ans.*) FILTER (WHERE ans.evaluated_at IS NOT NULL),
		        COALESCE(avg(CASE WHEN ans.is_correct THEN 1.0 ELSE 0.0 END)
		                 FILTER (WHERE ans.evaluated_at IS NOT NULL) * 100, 0),
		        COALESCE(avg(ans.points_awarded) FILTER (WHERE ans.evaluated_at IS NOT NULL), 0)
		 FROM assessment_questions aq
		 JOIN questions q ON q.id = aq.question_id
		 LEFT JOIN attempt_answers ans ON ans.assessment_question_id = aq.id
		 LEFT JOIN assessment_attempts at ON at.id = ans.attempt_id AND at.status = 'evaluated'
		 WHERE aq.assessment_id = $1
		 GROUP BY q.id, q.title, q.type, aq.position
		 ORDER BY aq.position`, assessmentID)
	if err != nil {
		return out, fmt.Errorf("assessment: analytics questions: %w", err)
	}
	defer qRows.Close()
	for qRows.Next() {
		var qs QuestionStat
		if err := qRows.Scan(&qs.QuestionID, &qs.Title, &qs.Type, &qs.Answered, &qs.CorrectRate, &qs.AvgPoints); err != nil {
			return out, fmt.Errorf("assessment: scan question stat: %w", err)
		}
		out.QuestionStats = append(out.QuestionStats, qs)
	}
	if err := qRows.Err(); err != nil {
		return out, err
	}

	// Attempts with any critical proctoring event.
	if err := r.pool.QueryRow(ctx,
		`SELECT count(DISTINCT at.id)
		 FROM assessment_attempts at
		 JOIN attempt_events e ON e.attempt_id = at.id
		 WHERE at.assessment_id = $1 AND e.severity IN ('warning','critical')`,
		assessmentID).Scan(&out.FlaggedAttempts); err != nil {
		return out, fmt.Errorf("assessment: analytics flags: %w", err)
	}

	return out, nil
}

// StudentAnalytics is a learner's personal performance summary.
type StudentAnalytics struct {
	Completed     int     `json:"completed"`
	Passed        int     `json:"passed"`
	AvgPercentage float64 `json:"avg_percentage"`
	TotalTimeSec  int     `json:"total_time_sec"`
}

func (r *Repo) StudentAnalytics(ctx context.Context, orgID, userID string) (StudentAnalytics, error) {
	var out StudentAnalytics
	err := r.pool.QueryRow(ctx,
		`SELECT
		   count(*) FILTER (WHERE status = 'evaluated'),
		   count(*) FILTER (WHERE status = 'evaluated' AND passed),
		   COALESCE(avg(percentage) FILTER (WHERE status = 'evaluated'), 0),
		   COALESCE(sum(duration_seconds), 0)
		 FROM assessment_attempts
		 WHERE org_id = $1 AND user_id = $2`,
		orgID, userID).Scan(&out.Completed, &out.Passed, &out.AvgPercentage, &out.TotalTimeSec)
	if err != nil {
		return out, fmt.Errorf("assessment: student analytics: %w", err)
	}
	return out, nil
}

// OrgAnalytics is the organisation-wide assessment overview.
type OrgAnalytics struct {
	TotalAssessments int     `json:"total_assessments"`
	TotalQuestions   int     `json:"total_questions"`
	TotalAttempts    int     `json:"total_attempts"`
	AvgPassRate      float64 `json:"avg_pass_rate"`
	ActiveBatches    int     `json:"active_batches"`
}

func (r *Repo) OrgAnalytics(ctx context.Context, orgID string) (OrgAnalytics, error) {
	var out OrgAnalytics
	err := r.pool.QueryRow(ctx,
		`SELECT
		   (SELECT count(*) FROM assessments WHERE org_id = $1 AND status != 'archived'),
		   (SELECT count(*) FROM questions WHERE org_id = $1 AND status = 'active'),
		   (SELECT count(*) FROM assessment_attempts WHERE org_id = $1 AND status IN ('submitted','evaluated','expired')),
		   (SELECT COALESCE(avg(CASE WHEN passed THEN 1.0 ELSE 0.0 END) * 100, 0)
		      FROM assessment_attempts WHERE org_id = $1 AND status = 'evaluated'),
		   (SELECT count(*) FROM batches WHERE org_id = $1 AND status = 'active')`,
		orgID).Scan(&out.TotalAssessments, &out.TotalQuestions, &out.TotalAttempts,
		&out.AvgPassRate, &out.ActiveBatches)
	if err != nil {
		return out, fmt.Errorf("assessment: org analytics: %w", err)
	}
	return out, nil
}

// AttemptRow is a compact attempt record for staff result tables.
type AttemptRow struct {
	ID            string   `json:"id"`
	UserID        string   `json:"user_id"`
	UserName      string   `json:"user_name"`
	UserEmail     string   `json:"user_email"`
	Status        string   `json:"status"`
	AttemptNumber int      `json:"attempt_number"`
	Percentage    *float64 `json:"percentage"`
	Passed        *bool    `json:"passed"`
	DurationSec   int      `json:"duration_sec"`
	Flags         int      `json:"flags"`
}

// ListAssessmentAttempts returns every attempt for an assessment (staff view).
func (r *Repo) ListAssessmentAttempts(ctx context.Context, orgID, assessmentID string) ([]AttemptRow, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT at.id, at.user_id, u.name, u.email, at.status, at.attempt_number,
		        at.percentage, at.passed, at.duration_seconds,
		        (SELECT count(*) FROM attempt_events e
		           WHERE e.attempt_id = at.id AND e.severity IN ('warning','critical'))
		 FROM assessment_attempts at
		 JOIN users u ON u.id = at.user_id
		 JOIN assessments a ON a.id = at.assessment_id
		 WHERE at.assessment_id = $1 AND a.org_id = $2
		 ORDER BY at.created_at DESC`, assessmentID, orgID)
	if err != nil {
		return nil, fmt.Errorf("assessment: list attempts: %w", err)
	}
	defer rows.Close()

	out := []AttemptRow{}
	for rows.Next() {
		var a AttemptRow
		if err := rows.Scan(&a.ID, &a.UserID, &a.UserName, &a.UserEmail, &a.Status,
			&a.AttemptNumber, &a.Percentage, &a.Passed, &a.DurationSec, &a.Flags); err != nil {
			return nil, fmt.Errorf("assessment: scan attempt row: %w", err)
		}
		out = append(out, a)
	}
	return out, rows.Err()
}
