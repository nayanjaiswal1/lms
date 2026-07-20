package revisionplan

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// IsCourseComplete reports whether userID has completed every module in
// courseID — the gate Service.Generate checks before allowing a plan to be
// requested, since a revision plan only makes sense once there's a full
// course of performance signal to reason about.
func (r *Repo) IsCourseComplete(ctx context.Context, userID, courseID string) (bool, error) {
	var completed, total int
	err := r.pool.QueryRow(ctx,
		`SELECT
		   COUNT(*) FILTER (WHERE mp.status = 'completed'),
		   COUNT(*)
		 FROM course_modules cm
		 LEFT JOIN module_progress mp ON mp.module_id = cm.id AND mp.user_id = $2
		 WHERE cm.course_id = $1 AND cm.deleted_at IS NULL`,
		courseID, userID,
	).Scan(&completed, &total)
	if err != nil {
		return false, fmt.Errorf("revisionplan: is course complete: %w", err)
	}
	return total > 0 && completed == total, nil
}

// CreateOrResetShell creates the (user, course) plan row, or — if a plan was
// already requested before (e.g. a previous failed attempt, or the learner
// wants a fresh read after revisiting weak lessons) — resets it back to
// "generating" in place. Existing topics are left untouched until the new
// generation's ReplaceTopics call arrives, so a fetch mid-regeneration still
// shows the previous plan rather than a hole.
func (r *Repo) CreateOrResetShell(ctx context.Context, userID, courseID, orgID string) (RevisionPlan, error) {
	var p RevisionPlan
	err := r.pool.QueryRow(ctx,
		`INSERT INTO revision_plans (user_id, course_id, org_id, status)
		 VALUES ($1, $2, $3, $4)
		 ON CONFLICT (user_id, course_id) DO UPDATE
		   SET status = $4, generation_error = NULL, updated_at = now()
		 RETURNING id, user_id, course_id, org_id, status, generation_error, generated_at, created_at, updated_at`,
		userID, courseID, orgID, StatusGenerating,
	).Scan(&p.ID, &p.UserID, &p.CourseID, &p.OrgID, &p.Status, &p.GenerationError, &p.GeneratedAt, &p.CreatedAt, &p.UpdatedAt)
	if err != nil {
		return RevisionPlan{}, fmt.Errorf("revisionplan: create or reset shell: %w", err)
	}
	return p, nil
}

// GetByID fetches a plan by id, with no user ownership check — used by the
// background job handler, which only has the plan id (job.EntityID).
func (r *Repo) GetByID(ctx context.Context, id string) (RevisionPlan, error) {
	var p RevisionPlan
	err := r.pool.QueryRow(ctx,
		`SELECT id, user_id, course_id, org_id, status, generation_error, generated_at, created_at, updated_at
		 FROM revision_plans WHERE id = $1`, id,
	).Scan(&p.ID, &p.UserID, &p.CourseID, &p.OrgID, &p.Status, &p.GenerationError, &p.GeneratedAt, &p.CreatedAt, &p.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return RevisionPlan{}, ErrNotFound
		}
		return RevisionPlan{}, fmt.Errorf("revisionplan: get by id: %w", err)
	}
	return p, nil
}

// GetForUser returns userID's plan for courseID (with topics attached, once
// ready), or ErrNotFound if they've never requested one.
func (r *Repo) GetForUser(ctx context.Context, userID, courseID string) (RevisionPlan, error) {
	var p RevisionPlan
	err := r.pool.QueryRow(ctx,
		`SELECT id, user_id, course_id, org_id, status, generation_error, generated_at, created_at, updated_at
		 FROM revision_plans WHERE user_id = $1 AND course_id = $2`,
		userID, courseID,
	).Scan(&p.ID, &p.UserID, &p.CourseID, &p.OrgID, &p.Status, &p.GenerationError, &p.GeneratedAt, &p.CreatedAt, &p.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return RevisionPlan{}, ErrNotFound
		}
		return RevisionPlan{}, fmt.Errorf("revisionplan: get for user: %w", err)
	}
	if p.Status == StatusReady {
		topics, err := r.getTopics(ctx, p.ID)
		if err != nil {
			return RevisionPlan{}, err
		}
		p.Topics = topics
	}
	return p, nil
}

func (r *Repo) getTopics(ctx context.Context, planID string) ([]Topic, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, module_id, title, reason, recommendation, priority, position
		 FROM revision_plan_topics WHERE revision_plan_id = $1 ORDER BY position`,
		planID,
	)
	if err != nil {
		return nil, fmt.Errorf("revisionplan: get topics: %w", err)
	}
	defer rows.Close()
	topics := []Topic{}
	for rows.Next() {
		var t Topic
		if err := rows.Scan(&t.ID, &t.ModuleID, &t.Title, &t.Reason, &t.Recommendation, &t.Priority, &t.Position); err != nil {
			return nil, fmt.Errorf("revisionplan: scan topic: %w", err)
		}
		topics = append(topics, t)
	}
	return topics, rows.Err()
}

// MarkFailed records why generation failed so the frontend can show the
// learner a reason and a retry action.
func (r *Repo) MarkFailed(ctx context.Context, planID, reason string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE revision_plans SET status = $1, generation_error = $2, updated_at = now() WHERE id = $3`,
		StatusFailed, reason, planID)
	if err != nil {
		return fmt.Errorf("revisionplan: mark failed: %w", err)
	}
	return nil
}

// ReplaceTopics deletes any existing topics for planID and inserts the given
// ones, then flips the plan to "ready" — all in one transaction, so a reader
// never sees a plan marked ready with a half-inserted topic list.
func (r *Repo) ReplaceTopics(ctx context.Context, planID string, topics []Topic) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("revisionplan: begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if _, err := tx.Exec(ctx, `DELETE FROM revision_plan_topics WHERE revision_plan_id = $1`, planID); err != nil {
		return fmt.Errorf("revisionplan: delete existing topics: %w", err)
	}
	for _, t := range topics {
		if _, err := tx.Exec(ctx,
			`INSERT INTO revision_plan_topics (revision_plan_id, module_id, title, reason, recommendation, priority, position)
			 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
			planID, t.ModuleID, t.Title, t.Reason, t.Recommendation, t.Priority, t.Position,
		); err != nil {
			return fmt.Errorf("revisionplan: insert topic %d: %w", t.Position, err)
		}
	}
	if _, err := tx.Exec(ctx,
		`UPDATE revision_plans SET status = $1, generated_at = now(), generation_error = NULL, updated_at = now() WHERE id = $2`,
		StatusReady, planID,
	); err != nil {
		return fmt.Errorf("revisionplan: update plan status: %w", err)
	}
	return tx.Commit(ctx)
}

// GatherSignals reads userID's actual performance data for courseID — every
// notes-type lesson's knowledge-check accuracy plus their own reflection —
// restricted to lessons that have at least one of those two signals. This is
// the only data BuildPrompt is allowed to hand the AI.
func (r *Repo) GatherSignals(ctx context.Context, userID, courseID string) (CourseSignals, error) {
	var signals CourseSignals
	if err := r.pool.QueryRow(ctx, `SELECT title FROM courses WHERE id = $1`, courseID).Scan(&signals.CourseTitle); err != nil {
		return CourseSignals{}, fmt.Errorf("revisionplan: gather signals: course title: %w", err)
	}

	rows, err := r.pool.Query(ctx,
		`SELECT
		   cm.id, cm.title, cs.title,
		   COALESCE(lr.response, ''),
		   COUNT(DISTINCT lca.question_id),
		   COUNT(DISTINCT lca.question_id) FILTER (WHERE lca.is_correct),
		   COUNT(*) FILTER (WHERE lca.is_correct = false)
		 FROM course_modules cm
		 JOIN course_sections cs ON cs.id = cm.section_id
		 LEFT JOIN lesson_reflections lr ON lr.module_id = cm.id AND lr.user_id = $2
		 LEFT JOIN lesson_check_attempts lca ON lca.module_id = cm.id AND lca.user_id = $2
		 WHERE cm.course_id = $1 AND cm.type = 'notes' AND cm.deleted_at IS NULL
		 GROUP BY cm.id, cm.title, cs.title, lr.response, cs.position, cm.position
		 HAVING lr.response IS NOT NULL OR COUNT(lca.id) > 0
		 ORDER BY cs.position, cm.position`,
		courseID, userID,
	)
	if err != nil {
		return CourseSignals{}, fmt.Errorf("revisionplan: gather signals: modules: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var m ModuleSignal
		if err := rows.Scan(&m.ModuleID, &m.Title, &m.SectionTitle, &m.Reflection,
			&m.QuestionsTotal, &m.QuestionsEverCorrect, &m.WrongAttempts); err != nil {
			return CourseSignals{}, fmt.Errorf("revisionplan: gather signals: scan module: %w", err)
		}
		signals.Modules = append(signals.Modules, m)
	}
	if err := rows.Err(); err != nil {
		return CourseSignals{}, fmt.Errorf("revisionplan: gather signals: %w", err)
	}
	return signals, nil
}
