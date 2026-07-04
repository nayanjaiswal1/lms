package profile

import (
	"context"
	"fmt"
)

// ─── GetDifficultyBreakdown ────────────────────────────────────────────────────

// GetDifficultyBreakdown returns solved/total counts per question difficulty
// (zero-filled for every level in QuestionDifficultyLevels, even when the user
// has solved nothing at that level) plus the count of questions the user has
// attempted but never solved ("attempting").
func (r *Repo) GetDifficultyBreakdown(ctx context.Context, orgID, userID string) ([]DifficultyCount, int, error) {
	solved := make(map[string]int, len(QuestionDifficultyLevels))
	total := make(map[string]int, len(QuestionDifficultyLevels))

	const solvedQ = `
		SELECT q.difficulty, COUNT(DISTINCT aa.question_id)
		FROM attempt_answers aa
		JOIN assessment_attempts at ON at.id = aa.attempt_id
		JOIN questions q ON q.id = aa.question_id
		WHERE at.user_id = $1 AND aa.is_correct = true
		GROUP BY q.difficulty`

	rows, err := r.pool.Query(ctx, solvedQ, userID)
	if err != nil {
		return nil, 0, fmt.Errorf("profile: get solved by difficulty: %w", err)
	}
	for rows.Next() {
		var difficulty string
		var count int
		if err := rows.Scan(&difficulty, &count); err != nil {
			rows.Close()
			return nil, 0, fmt.Errorf("profile: scan solved by difficulty: %w", err)
		}
		solved[difficulty] = count
	}
	if err := rows.Err(); err != nil {
		rows.Close()
		return nil, 0, fmt.Errorf("profile: iterate solved by difficulty: %w", err)
	}
	rows.Close()

	const totalQ = `
		SELECT difficulty, COUNT(*)
		FROM questions
		WHERE org_id = $1 AND status = 'active'
		GROUP BY difficulty`

	totalRows, err := r.pool.Query(ctx, totalQ, orgID)
	if err != nil {
		return nil, 0, fmt.Errorf("profile: get question totals by difficulty: %w", err)
	}
	for totalRows.Next() {
		var difficulty string
		var count int
		if err := totalRows.Scan(&difficulty, &count); err != nil {
			totalRows.Close()
			return nil, 0, fmt.Errorf("profile: scan question totals by difficulty: %w", err)
		}
		total[difficulty] = count
	}
	if err := totalRows.Err(); err != nil {
		totalRows.Close()
		return nil, 0, fmt.Errorf("profile: iterate question totals by difficulty: %w", err)
	}
	totalRows.Close()

	breakdown := make([]DifficultyCount, 0, len(QuestionDifficultyLevels))
	for _, level := range QuestionDifficultyLevels {
		breakdown = append(breakdown, DifficultyCount{
			Difficulty: level,
			Solved:     solved[level],
			Total:      total[level],
		})
	}

	const attemptingQ = `
		SELECT COUNT(*)
		FROM (
			SELECT aa.question_id
			FROM attempt_answers aa
			JOIN assessment_attempts at ON at.id = aa.attempt_id
			WHERE at.user_id = $1
			GROUP BY aa.question_id
			HAVING bool_or(aa.is_correct) IS NOT TRUE
		) x`

	var attempting int
	if err := r.pool.QueryRow(ctx, attemptingQ, userID).Scan(&attempting); err != nil {
		return nil, 0, fmt.Errorf("profile: get attempting count: %w", err)
	}

	return breakdown, attempting, nil
}

// ─── GetSubmissionCalendar ──────────────────────────────────────────────────────

// GetSubmissionCalendar returns one entry per active day in the trailing 365
// days, ordered ascending by date, with the count of attempts submitted or
// finalized that day.
func (r *Repo) GetSubmissionCalendar(ctx context.Context, userID string) ([]CalendarDay, error) {
	const q = `
		SELECT COALESCE(submitted_at, created_at)::date AS d, COUNT(*)
		FROM assessment_attempts
		WHERE user_id = $1
			AND COALESCE(submitted_at, created_at) >= now() - interval '365 days'
			AND status IN ('submitted', 'evaluated', 'expired')
		GROUP BY d
		ORDER BY d ASC`

	rows, err := r.pool.Query(ctx, q, userID)
	if err != nil {
		return nil, fmt.Errorf("profile: get submission calendar: %w", err)
	}
	defer rows.Close()

	var days []CalendarDay
	for rows.Next() {
		var d CalendarDay
		if err := rows.Scan(&d.Date, &d.Count); err != nil {
			return nil, fmt.Errorf("profile: scan calendar day: %w", err)
		}
		days = append(days, d)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("profile: iterate calendar days: %w", err)
	}
	if days == nil {
		days = []CalendarDay{}
	}
	return days, nil
}

// ─── GetRecentActivity ──────────────────────────────────────────────────────────

// GetRecentActivity returns the user's most recent assessment attempts,
// newest first, joined to the assessment title.
func (r *Repo) GetRecentActivity(ctx context.Context, userID string, limit int) ([]RecentActivityItem, error) {
	const q = `
		SELECT at.id, a.title, at.status, at.passed, at.percentage,
			COALESCE(at.submitted_at, at.created_at) AS occurred_at
		FROM assessment_attempts at
		JOIN assessments a ON a.id = at.assessment_id
		WHERE at.user_id = $1
			AND at.status IN ('submitted', 'evaluated', 'expired', 'in_progress')
		ORDER BY occurred_at DESC
		LIMIT $2`

	rows, err := r.pool.Query(ctx, q, userID, limit)
	if err != nil {
		return nil, fmt.Errorf("profile: get recent activity: %w", err)
	}
	defer rows.Close()

	var items []RecentActivityItem
	for rows.Next() {
		var item RecentActivityItem
		if err := rows.Scan(
			&item.AttemptID, &item.AssessmentTitle, &item.Status,
			&item.Passed, &item.Percentage, &item.OccurredAt,
		); err != nil {
			return nil, fmt.Errorf("profile: scan recent activity: %w", err)
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("profile: iterate recent activity: %w", err)
	}
	if items == nil {
		items = []RecentActivityItem{}
	}
	return items, nil
}
