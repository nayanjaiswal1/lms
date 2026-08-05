package interviewprep

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("interviewprep: not found")

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// CountRecentPlans returns how many plans the user created in the last 24h,
// for the handler's rate limit (5/day, same lightweight COUNT-based cap used
// by the practice and labs packages).
func (r *Repo) CountRecentPlans(ctx context.Context, userID string) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM interview_prep_plans
		 WHERE user_id = $1 AND created_at > now() - interval '1 day'`,
		userID,
	).Scan(&n)
	if err != nil {
		return 0, fmt.Errorf("interviewprep: count recent plans: %w", err)
	}
	return n, nil
}

// CreatePlanWithRounds inserts a plan and its rounds in a single transaction —
// a plan is never useful without its rounds, so partial creation must not persist.
func (r *Repo) CreatePlanWithRounds(ctx context.Context, plan Plan, rounds []Round) (Plan, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return Plan{}, fmt.Errorf("interviewprep: begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	err = tx.QueryRow(ctx,
		`INSERT INTO interview_prep_plans
		   (user_id, org_id, plan_type, category, job_title, jd_text, technology, difficulty,
		    extracted_role, extracted_seniority, extracted_skills, status, ai_model)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
		 RETURNING id, created_at`,
		plan.UserID, plan.OrgID, plan.PlanType, plan.Category, plan.JobTitle, plan.JDText, plan.Technology, plan.Difficulty,
		plan.ExtractedRole, plan.ExtractedSeniority, plan.ExtractedSkills, plan.Status, plan.AIModel,
	).Scan(&plan.ID, &plan.CreatedAt)
	if err != nil {
		return Plan{}, fmt.Errorf("interviewprep: create plan: %w", err)
	}

	out := make([]Round, 0, len(rounds))
	for _, rnd := range rounds {
		rnd.PlanID = plan.ID
		itemsRaw, err := json.Marshal(rnd.Items)
		if err != nil {
			return Plan{}, fmt.Errorf("interviewprep: marshal round items: %w", err)
		}
		// ponytail: practice_session_id column now stores assessment_attempt_id.
		// Schema rename deferred to follow-up migration once all callers are updated.
		err = tx.QueryRow(ctx,
			`INSERT INTO interview_prep_rounds
			   (plan_id, round_type, order_index, practice_session_id, items, status)
			 VALUES ($1, $2, $3, $4, $5, $6)
			 RETURNING id, created_at`,
			rnd.PlanID, rnd.RoundType, rnd.OrderIndex, rnd.PracticeSessionID, itemsRaw, rnd.Status,
		).Scan(&rnd.ID, &rnd.CreatedAt)
		if err != nil {
			return Plan{}, fmt.Errorf("interviewprep: create round %d: %w", rnd.OrderIndex, err)
		}
		out = append(out, rnd)
	}

	if err := tx.Commit(ctx); err != nil {
		return Plan{}, fmt.Errorf("interviewprep: commit tx: %w", err)
	}

	plan.Rounds = out
	return plan, nil
}

func scanPlan(row pgx.Row) (Plan, error) {
	var p Plan
	var reportRaw []byte
	err := row.Scan(&p.ID, &p.UserID, &p.OrgID, &p.PlanType, &p.Category, &p.JobTitle, &p.JDText, &p.Technology, &p.Difficulty,
		&p.ExtractedRole, &p.ExtractedSeniority, &p.ExtractedSkills, &p.Status, &reportRaw, &p.AIModel,
		&p.CreatedAt, &p.CompletedAt)
	if err != nil {
		return Plan{}, err
	}
	if reportRaw != nil {
		var rep Report
		if err := json.Unmarshal(reportRaw, &rep); err == nil {
			p.Report = &rep
		}
	}
	return p, nil
}

const planColumns = `id, user_id, org_id, plan_type, category, job_title, jd_text, technology, difficulty,
	extracted_role, extracted_seniority, extracted_skills, status, report, ai_model, created_at, completed_at`

// GetPlan fetches a plan owned by userID, including its rounds ordered by stage.
func (r *Repo) GetPlan(ctx context.Context, planID, userID string) (Plan, error) {
	plan, err := scanPlan(r.pool.QueryRow(ctx,
		`SELECT `+planColumns+` FROM interview_prep_plans WHERE id = $1 AND user_id = $2`,
		planID, userID,
	))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Plan{}, ErrNotFound
		}
		return Plan{}, fmt.Errorf("interviewprep: get plan: %w", err)
	}

	rounds, err := r.getRounds(ctx, planID)
	if err != nil {
		return Plan{}, err
	}
	plan.Rounds = rounds
	return plan, nil
}

// ListPlans returns the user's plans, most recent first, without round detail.
func (r *Repo) ListPlans(ctx context.Context, userID string) ([]Plan, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+planColumns+` FROM interview_prep_plans
		 WHERE user_id = $1 ORDER BY created_at DESC`, userID)
	if err != nil {
		return nil, fmt.Errorf("interviewprep: list plans: %w", err)
	}
	defer rows.Close()

	out := []Plan{}
	for rows.Next() {
		p, err := scanPlan(rows)
		if err != nil {
			return nil, fmt.Errorf("interviewprep: scan plan: %w", err)
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

func (r *Repo) getRounds(ctx context.Context, planID string) ([]Round, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, plan_id, round_type, order_index, practice_session_id, items, status, score, created_at, completed_at
		 FROM interview_prep_rounds WHERE plan_id = $1 ORDER BY order_index`, planID)
	if err != nil {
		return nil, fmt.Errorf("interviewprep: get rounds: %w", err)
	}
	defer rows.Close()

	out := []Round{}
	for rows.Next() {
		rnd, err := scanRound(rows)
		if err != nil {
			return nil, fmt.Errorf("interviewprep: scan round: %w", err)
		}
		out = append(out, rnd)
	}
	return out, rows.Err()
}

func scanRound(row pgx.Row) (Round, error) {
	var rnd Round
	var itemsRaw []byte
	err := row.Scan(&rnd.ID, &rnd.PlanID, &rnd.RoundType, &rnd.OrderIndex, &rnd.PracticeSessionID,
		&itemsRaw, &rnd.Status, &rnd.Score, &rnd.CreatedAt, &rnd.CompletedAt)
	if err != nil {
		return Round{}, err
	}
	rnd.Items = []CodingItem{}
	if len(itemsRaw) > 0 {
		if err := json.Unmarshal(itemsRaw, &rnd.Items); err != nil {
			return Round{}, fmt.Errorf("interviewprep: unmarshal round items: %w", err)
		}
	}
	return rnd, nil
}

// GetRoundForUser fetches a round, verifying it belongs to a plan owned by userID.
func (r *Repo) GetRoundForUser(ctx context.Context, roundID, planID, userID string) (Round, error) {
	rnd, err := scanRound(r.pool.QueryRow(ctx,
		`SELECT r.id, r.plan_id, r.round_type, r.order_index, r.practice_session_id, r.items, r.status, r.score, r.created_at, r.completed_at
		 FROM interview_prep_rounds r
		 JOIN interview_prep_plans p ON p.id = r.plan_id
		 WHERE r.id = $1 AND r.plan_id = $2 AND p.user_id = $3`,
		roundID, planID, userID,
	))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Round{}, ErrNotFound
		}
		return Round{}, fmt.Errorf("interviewprep: get round: %w", err)
	}
	return rnd, nil
}

// SaveRoundItems persists the (possibly partially-submitted) items array and,
// when completed is true, flips the round to completed with the given score.
func (r *Repo) SaveRoundItems(ctx context.Context, roundID string, items []CodingItem, completed bool, score *float64) error {
	itemsRaw, err := json.Marshal(items)
	if err != nil {
		return fmt.Errorf("interviewprep: marshal round items: %w", err)
	}
	if completed {
		_, err = r.pool.Exec(ctx,
			`UPDATE interview_prep_rounds
			 SET items = $1, status = $2, score = $3, completed_at = now()
			 WHERE id = $4`,
			itemsRaw, RoundCompleted, score, roundID)
	} else {
		_, err = r.pool.Exec(ctx,
			`UPDATE interview_prep_rounds SET items = $1, status = $2 WHERE id = $3`,
			itemsRaw, RoundActive, roundID)
	}
	if err != nil {
		return fmt.Errorf("interviewprep: save round items: %w", err)
	}
	return nil
}

// SaveReport stores the aggregate report exactly once. If another request has
// already written it (report IS NOT NULL), this is a no-op — the caller should
// re-fetch the plan rather than trust its own in-memory report.
func (r *Repo) SaveReport(ctx context.Context, planID string, report Report) (bool, error) {
	raw, err := json.Marshal(report)
	if err != nil {
		return false, fmt.Errorf("interviewprep: marshal report: %w", err)
	}
	tag, err := r.pool.Exec(ctx,
		`UPDATE interview_prep_plans
		 SET report = $1, status = $2, completed_at = now()
		 WHERE id = $3 AND report IS NULL`,
		raw, StatusCompleted, planID)
	if err != nil {
		return false, fmt.Errorf("interviewprep: save report: %w", err)
	}
	return tag.RowsAffected() > 0, nil
}
