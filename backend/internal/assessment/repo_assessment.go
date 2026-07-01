package assessment

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
)

func (r *Repo) CreateAssessment(ctx context.Context, a Assessment) (Assessment, error) {
	proctoring, err := json.Marshal(a.Proctoring)
	if err != nil {
		return Assessment{}, fmt.Errorf("assessment: marshal proctoring: %w", err)
	}
	err = r.pool.QueryRow(ctx,
		`INSERT INTO assessments
		   (org_id, title, slug, description, type, parent_type, parent_id,
		    duration_minutes, pass_percentage, max_attempts, shuffle_questions,
		    shuffle_options, allow_backtrack, show_results, starts_at, ends_at,
		    proctoring, created_by, mock_mode, short_code)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20)
		 RETURNING id, status, total_points, created_at, updated_at`,
		a.OrgID, a.Title, a.Slug, a.Description, a.Type, a.ParentType, a.ParentID,
		a.DurationMinutes, a.PassPercentage, a.MaxAttempts, a.ShuffleQuestions,
		a.ShuffleOptions, a.AllowBacktrack, a.ShowResults, a.StartsAt, a.EndsAt,
		proctoring, a.CreatedBy, a.MockMode, a.ShortCode,
	).Scan(&a.ID, &a.Status, &a.TotalPoints, &a.CreatedAt, &a.UpdatedAt)
	if err != nil {
		return Assessment{}, fmt.Errorf("assessment: create assessment: %w", err)
	}
	return a, nil
}

func (r *Repo) UpdateAssessment(ctx context.Context, orgID string, a Assessment) (Assessment, error) {
	proctoring, err := json.Marshal(a.Proctoring)
	if err != nil {
		return Assessment{}, fmt.Errorf("assessment: marshal proctoring: %w", err)
	}
	tag, err := r.pool.Exec(ctx,
		`UPDATE assessments SET
		   title = $3, description = $4, parent_type = $5, parent_id = $6,
		   duration_minutes = $7, pass_percentage = $8, max_attempts = $9,
		   shuffle_questions = $10, shuffle_options = $11, allow_backtrack = $12,
		   show_results = $13, starts_at = $14, ends_at = $15, proctoring = $16,
		   mock_mode = $17, updated_at = now()
		 WHERE id = $1 AND org_id = $2 AND status = 'draft'`,
		a.ID, orgID, a.Title, a.Description, a.ParentType, a.ParentID,
		a.DurationMinutes, a.PassPercentage, a.MaxAttempts, a.ShuffleQuestions,
		a.ShuffleOptions, a.AllowBacktrack, a.ShowResults, a.StartsAt, a.EndsAt, proctoring, a.MockMode)
	if err != nil {
		return Assessment{}, fmt.Errorf("assessment: update assessment: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return Assessment{}, ErrNotFound
	}
	return r.GetAssessment(ctx, orgID, a.ID)
}

func (r *Repo) GetAssessment(ctx context.Context, orgID, id string) (Assessment, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT a.id, a.org_id, a.title, a.slug, a.description, a.type, a.status,
		        a.parent_type, a.parent_id, a.duration_minutes, a.pass_percentage,
		        a.max_attempts, a.total_points, a.mock_mode, a.shuffle_questions, a.shuffle_options,
		        a.allow_backtrack, a.show_results, a.starts_at, a.ends_at, a.proctoring,
		        a.created_by, a.published_at, a.created_at, a.updated_at,
		        (SELECT count(*) FROM assessment_questions aq WHERE aq.assessment_id = a.id),
		        a.short_code
		 FROM assessments a WHERE a.id = $1 AND a.org_id = $2`, id, orgID)
	return scanAssessment(row)
}

// AssessmentFilter narrows a staff assessment listing.
type AssessmentFilter struct {
	Status     string
	Type       string
	ParentType string
	ParentID   string
	Search     string
	Limit      int
	Offset     int
}

func (r *Repo) ListAssessments(ctx context.Context, orgID string, f AssessmentFilter) ([]Assessment, error) {
	conds := []string{"a.org_id = $1"}
	args := []any{orgID}
	add := func(clause string, val any) {
		args = append(args, val)
		conds = append(conds, fmt.Sprintf(clause, len(args)))
	}
	if f.Status != "" {
		add("a.status = $%d", f.Status)
	}
	if f.Type != "" {
		add("a.type = $%d", f.Type)
	}
	if f.ParentType != "" {
		add("a.parent_type = $%d", f.ParentType)
	}
	if f.ParentID != "" {
		add("a.parent_id = $%d", f.ParentID)
	}
	if f.Search != "" {
		add("a.title ILIKE $%d", "%"+f.Search+"%")
	}
	where := strings.Join(conds, " AND ")

	limit := f.Limit
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	args = append(args, limit, f.Offset)
	query := fmt.Sprintf(
		`SELECT a.id, a.org_id, a.title, a.slug, a.description, a.type, a.status,
		        a.parent_type, a.parent_id, a.duration_minutes, a.pass_percentage,
		        a.max_attempts, a.total_points, a.mock_mode, a.shuffle_questions, a.shuffle_options,
		        a.allow_backtrack, a.show_results, a.starts_at, a.ends_at, a.proctoring,
		        a.created_by, a.published_at, a.created_at, a.updated_at,
		        (SELECT count(*) FROM assessment_questions aq WHERE aq.assessment_id = a.id),
		        a.short_code
		 FROM assessments a WHERE %s
		 ORDER BY a.updated_at DESC
		 LIMIT $%d OFFSET $%d`, where, len(args)-1, len(args))

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("assessment: list assessments: %w", err)
	}
	defer rows.Close()

	out := []Assessment{}
	for rows.Next() {
		a, err := scanAssessment(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

// SetStatus transitions the assessment lifecycle. publishedAt is set when moving
// into a live state for the first time.
func (r *Repo) SetStatus(ctx context.Context, orgID, id, status string, setPublished bool) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE assessments SET status = $3,
		   published_at = CASE WHEN $4 AND published_at IS NULL THEN now() ELSE published_at END,
		   updated_at = now()
		 WHERE id = $1 AND org_id = $2`, id, orgID, status, setPublished)
	if err != nil {
		return fmt.Errorf("assessment: set status: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ─── Assessment questions ────────────────────────────────────────────────────

// AssessmentQuestion is the ordered join row plus the pinned version content.
type AssessmentQuestion struct {
	ID            string          `json:"id"`
	AssessmentID  string          `json:"assessment_id"`
	QuestionID    string          `json:"question_id"`
	VersionID     string          `json:"version_id"`
	Position      int             `json:"position"`
	Points        float64         `json:"points"`
	Type          string          `json:"type"`
	Title         string          `json:"title"`
	Difficulty    string          `json:"difficulty"`
	Content       json.RawMessage `json:"content,omitempty"`
}

// AddQuestion pins the current version of a question into the assessment and
// recomputes total_points. Only draft assessments may be edited.
func (r *Repo) AddQuestion(ctx context.Context, orgID, assessmentID, questionID string, points *float64) (AssessmentQuestion, error) {
	var aq AssessmentQuestion
	err := r.tx(ctx, func(tx pgx.Tx) error {
		var status string
		var version int
		var defaultPoints float64
		if err := tx.QueryRow(ctx,
			`SELECT a.status, q.current_version, q.default_points
			 FROM assessments a, questions q
			 WHERE a.id = $1 AND a.org_id = $3 AND q.id = $2 AND q.org_id = $3`,
			assessmentID, questionID, orgID).Scan(&status, &version, &defaultPoints); err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return ErrNotFound
			}
			return fmt.Errorf("assessment: load add-question context: %w", err)
		}
		if status != StatusDraft {
			return ErrNotDraft
		}

		var versionID string
		var content []byte
		if err := tx.QueryRow(ctx,
			`SELECT id, content FROM question_versions WHERE question_id = $1 AND version = $2`,
			questionID, version).Scan(&versionID, &content); err != nil {
			return fmt.Errorf("assessment: resolve question version: %w", err)
		}

		pts := defaultPoints
		if points != nil {
			pts = *points
		}

		if err := tx.QueryRow(ctx,
			`INSERT INTO assessment_questions
			   (assessment_id, question_id, version_id, position, points)
			 VALUES ($1, $2, $3,
			   COALESCE((SELECT max(position)+1 FROM assessment_questions WHERE assessment_id = $1), 0),
			   $4)
			 RETURNING id, position`,
			assessmentID, questionID, versionID, pts).Scan(&aq.ID, &aq.Position); err != nil {
			return fmt.Errorf("assessment: insert assessment question: %w", err)
		}

		aq.AssessmentID = assessmentID
		aq.QuestionID = questionID
		aq.VersionID = versionID
		aq.Points = pts
		aq.Content = content

		return recomputeTotals(ctx, tx, assessmentID)
	})
	if err != nil {
		return AssessmentQuestion{}, err
	}
	return aq, nil
}

// RemoveQuestion detaches a question and recomputes totals (draft only).
func (r *Repo) RemoveQuestion(ctx context.Context, orgID, assessmentID, assessmentQuestionID string) error {
	return r.tx(ctx, func(tx pgx.Tx) error {
		var status string
		if err := tx.QueryRow(ctx,
			`SELECT status FROM assessments WHERE id = $1 AND org_id = $2`,
			assessmentID, orgID).Scan(&status); err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return ErrNotFound
			}
			return fmt.Errorf("assessment: load assessment status: %w", err)
		}
		if status != StatusDraft {
			return ErrNotDraft
		}
		tag, err := tx.Exec(ctx,
			`DELETE FROM assessment_questions WHERE id = $1 AND assessment_id = $2`,
			assessmentQuestionID, assessmentID)
		if err != nil {
			return fmt.Errorf("assessment: delete assessment question: %w", err)
		}
		if tag.RowsAffected() == 0 {
			return ErrNotFound
		}
		return recomputeTotals(ctx, tx, assessmentID)
	})
}

// ListAssessmentQuestions returns the ordered questions with pinned content.
func (r *Repo) ListAssessmentQuestions(ctx context.Context, assessmentID string) ([]AssessmentQuestion, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT aq.id, aq.assessment_id, aq.question_id, aq.version_id, aq.position,
		        aq.points, q.type, q.title, q.difficulty, qv.content
		 FROM assessment_questions aq
		 JOIN questions q ON q.id = aq.question_id
		 JOIN question_versions qv ON qv.id = aq.version_id
		 WHERE aq.assessment_id = $1
		 ORDER BY aq.position`, assessmentID)
	if err != nil {
		return nil, fmt.Errorf("assessment: list assessment questions: %w", err)
	}
	defer rows.Close()

	out := []AssessmentQuestion{}
	for rows.Next() {
		var aq AssessmentQuestion
		var content []byte
		if err := rows.Scan(&aq.ID, &aq.AssessmentID, &aq.QuestionID, &aq.VersionID,
			&aq.Position, &aq.Points, &aq.Type, &aq.Title, &aq.Difficulty, &content); err != nil {
			return nil, fmt.Errorf("assessment: scan assessment question: %w", err)
		}
		aq.Content = content
		out = append(out, aq)
	}
	return out, rows.Err()
}

// recomputeTotals refreshes total_points and the derived type (mcq/coding/mixed).
func recomputeTotals(ctx context.Context, tx pgx.Tx, assessmentID string) error {
	_, err := tx.Exec(ctx,
		`UPDATE assessments a SET
		   total_points = COALESCE((SELECT sum(points) FROM assessment_questions WHERE assessment_id = a.id), 0),
		   type = COALESCE((
		     SELECT CASE
		       WHEN count(*) FILTER (WHERE q.type = 'mcq') > 0
		        AND count(*) FILTER (WHERE q.type = 'coding') > 0 THEN 'mixed'
		       WHEN count(*) FILTER (WHERE q.type = 'coding') > 0 THEN 'coding'
		       ELSE 'mcq' END
		     FROM assessment_questions aq JOIN questions q ON q.id = aq.question_id
		     WHERE aq.assessment_id = a.id
		   ), a.type),
		   updated_at = now()
		 WHERE a.id = $1`, assessmentID)
	if err != nil {
		return fmt.Errorf("assessment: recompute totals: %w", err)
	}
	return nil
}

// ─── Assignments ─────────────────────────────────────────────────────────────

// Assignment is who must take an assessment.
type Assignment struct {
	ID            string     `json:"id"`
	AssessmentID  string     `json:"assessment_id"`
	AssigneeType  string     `json:"assignee_type"`
	AssigneeID    string     `json:"assignee_id"`
	AssigneeName  string     `json:"assignee_name"`
	DueAt         *string    `json:"due_at"`
	AssignedBy    string     `json:"assigned_by"`
}

// CreateAssignments inserts assignments for multiple assignees in one transaction,
// verifying org ownership of the assessment once before any writes.
func (r *Repo) CreateAssignments(ctx context.Context, orgID, assessmentID, assigneeType string, assigneeIDs []string, assignedBy string, dueAt *string) ([]string, error) {
	ids := make([]string, 0, len(assigneeIDs))
	err := r.tx(ctx, func(tx pgx.Tx) error {
		// Guard org ownership once for the whole batch.
		var owns bool
		if err := tx.QueryRow(ctx,
			`SELECT EXISTS(SELECT 1 FROM assessments WHERE id = $1 AND org_id = $2)`,
			assessmentID, orgID).Scan(&owns); err != nil {
			return fmt.Errorf("assessment: verify assessment org: %w", err)
		}
		if !owns {
			return ErrNotFound
		}

		for _, assigneeID := range assigneeIDs {
			var id string
			if err := tx.QueryRow(ctx,
				`INSERT INTO assessment_assignments
				   (assessment_id, assignee_type, assignee_id, due_at, assigned_by)
				 VALUES ($1, $2, $3, $4, $5)
				 ON CONFLICT (assessment_id, assignee_type, assignee_id)
				 DO UPDATE SET due_at = EXCLUDED.due_at
				 RETURNING id`,
				assessmentID, assigneeType, assigneeID, dueAt, assignedBy).Scan(&id); err != nil {
				return fmt.Errorf("assessment: create assignment: %w", err)
			}
			ids = append(ids, id)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return ids, nil
}

func (r *Repo) ListAssignments(ctx context.Context, orgID, assessmentID string) ([]Assignment, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT aa.id, aa.assessment_id, aa.assignee_type, aa.assignee_id,
		        COALESCE(u.name, b.name, '') AS assignee_name,
		        aa.due_at::text, aa.assigned_by
		 FROM assessment_assignments aa
		 JOIN assessments a ON a.id = aa.assessment_id AND a.org_id = $1
		 LEFT JOIN users u ON aa.assignee_type = 'student' AND u.id = aa.assignee_id
		 LEFT JOIN batches b ON aa.assignee_type = 'batch' AND b.id = aa.assignee_id
		 WHERE aa.assessment_id = $2
		 ORDER BY aa.assigned_at DESC`, orgID, assessmentID)
	if err != nil {
		return nil, fmt.Errorf("assessment: list assignments: %w", err)
	}
	defer rows.Close()

	out := []Assignment{}
	for rows.Next() {
		var a Assignment
		if err := rows.Scan(&a.ID, &a.AssessmentID, &a.AssigneeType, &a.AssigneeID,
			&a.AssigneeName, &a.DueAt, &a.AssignedBy); err != nil {
			return nil, fmt.Errorf("assessment: scan assignment: %w", err)
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

func (r *Repo) DeleteAssignment(ctx context.Context, orgID, assessmentID, assignmentID string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM assessment_assignments aa
		 USING assessments a
		 WHERE aa.id = $1 AND aa.assessment_id = $2 AND a.id = aa.assessment_id AND a.org_id = $3`,
		assignmentID, assessmentID, orgID)
	if err != nil {
		return fmt.Errorf("assessment: delete assignment: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// IsUserAssigned reports whether the user may take the assessment.
// Access is granted if any of these conditions hold:
//  1. The user has a direct or batch assignment in assessment_assignments.
//  2. The assessment is linked to a course module and the user is enrolled in that course.
func (r *Repo) IsUserAssigned(ctx context.Context, assessmentID, userID string) (bool, error) {
	var ok bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(
		   SELECT 1 FROM assessment_assignments aa
		   WHERE aa.assessment_id = $1
		     AND (
		       (aa.assignee_type = 'student' AND aa.assignee_id = $2)
		       OR (aa.assignee_type = 'batch' AND aa.assignee_id IN (
		             SELECT batch_id FROM batch_members WHERE user_id = $2))
		     )
		 )
		 OR EXISTS(
		   SELECT 1 FROM course_modules cm
		   JOIN enrollments e ON e.course_id = cm.course_id
		   WHERE cm.assessment_id = $1
		     AND e.user_id = $2
		 )`, assessmentID, userID).Scan(&ok)
	if err != nil {
		return false, fmt.Errorf("assessment: check assignment: %w", err)
	}
	return ok, nil
}

// scanAssessment maps a row (from QueryRow or Rows) into an Assessment, decoding
// the proctoring JSONB. The column order must match the SELECT lists above.
func scanAssessment(row pgx.Row) (Assessment, error) {
	var a Assessment
	var proctoring []byte
	err := row.Scan(&a.ID, &a.OrgID, &a.Title, &a.Slug, &a.Description, &a.Type, &a.Status,
		&a.ParentType, &a.ParentID, &a.DurationMinutes, &a.PassPercentage,
		&a.MaxAttempts, &a.TotalPoints, &a.MockMode, &a.ShuffleQuestions, &a.ShuffleOptions,
		&a.AllowBacktrack, &a.ShowResults, &a.StartsAt, &a.EndsAt, &proctoring,
		&a.CreatedBy, &a.PublishedAt, &a.CreatedAt, &a.UpdatedAt, &a.QuestionCount, &a.ShortCode)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Assessment{}, ErrNotFound
		}
		return Assessment{}, fmt.Errorf("assessment: scan assessment: %w", err)
	}
	a.Proctoring = DefaultProctoring()
	if len(proctoring) > 0 {
		if err := json.Unmarshal(proctoring, &a.Proctoring); err != nil {
			return Assessment{}, fmt.Errorf("assessment: decode proctoring: %w", err)
		}
	}
	return a, nil
}
