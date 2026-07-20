package roadmap

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound          = errors.New("roadmap: not found")
	ErrAlreadyGenerating = errors.New("roadmap: already generating")
)

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// CountRecentRoadmaps returns how many roadmaps the user created in the last
// 24h, for the handler's daily creation cap (same pattern as
// interviewprep.maxPlansPerDay).
func (r *Repo) CountRecentRoadmaps(ctx context.Context, userID string) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM roadmaps WHERE user_id = $1 AND created_at > now() - interval '1 day'`,
		userID,
	).Scan(&n)
	if err != nil {
		return 0, fmt.Errorf("roadmap: count recent roadmaps: %w", err)
	}
	return n, nil
}

func marshalFocusAreas(areas []string) ([]byte, error) {
	if areas == nil {
		areas = []string{}
	}
	return json.Marshal(areas)
}

// CreateShell inserts a roadmap row in status=generating with no
// phases/milestones/modules yet — the async job fills those in.
func (r *Repo) CreateShell(ctx context.Context, rm Roadmap) (Roadmap, error) {
	focusRaw, err := marshalFocusAreas(rm.FocusAreas)
	if err != nil {
		return Roadmap{}, fmt.Errorf("roadmap: marshal focus_areas: %w", err)
	}
	err = r.pool.QueryRow(ctx,
		`INSERT INTO roadmaps
		   (user_id, org_id, title, mode, status, goal_description, target_role, skill_level, timeframe_weeks, focus_areas)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		 RETURNING id, created_at, updated_at`,
		rm.UserID, rm.OrgID, rm.Title, ModeGenerated, StatusGenerating, rm.GoalDescription,
		rm.TargetRole, rm.SkillLevel, rm.TimeframeWeeks, focusRaw,
	).Scan(&rm.ID, &rm.CreatedAt, &rm.UpdatedAt)
	if err != nil {
		return Roadmap{}, fmt.Errorf("roadmap: create shell: %w", err)
	}
	rm.Mode = ModeGenerated
	rm.Status = StatusGenerating
	return rm, nil
}

// CreateFromFork inserts a roadmap row that starts life already 'active' —
// used when a user starts a public roadmap: the tree is copied from the
// source (via ReplaceGeneratedTree), not AI-generated, so there is nothing to
// wait on.
func (r *Repo) CreateFromFork(ctx context.Context, rm Roadmap) (Roadmap, error) {
	focusRaw, err := marshalFocusAreas(rm.FocusAreas)
	if err != nil {
		return Roadmap{}, fmt.Errorf("roadmap: marshal focus_areas: %w", err)
	}
	err = r.pool.QueryRow(ctx,
		`INSERT INTO roadmaps
		   (user_id, org_id, title, mode, status, goal_description, target_role, skill_level, timeframe_weeks, focus_areas, generated_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, now())
		 RETURNING id, created_at, updated_at`,
		rm.UserID, rm.OrgID, rm.Title, ModeDefined, StatusActive, rm.GoalDescription,
		rm.TargetRole, rm.SkillLevel, rm.TimeframeWeeks, focusRaw,
	).Scan(&rm.ID, &rm.CreatedAt, &rm.UpdatedAt)
	if err != nil {
		return Roadmap{}, fmt.Errorf("roadmap: create from fork: %w", err)
	}
	rm.Mode = ModeDefined
	rm.Status = StatusActive
	return rm, nil
}

const roadmapColumns = `id, user_id, org_id, title, mode, status, is_public, goal_description, target_role,
	skill_level, timeframe_weeks, focus_areas, generation_error, generated_at, created_at, updated_at`

func scanRoadmap(row pgx.Row) (Roadmap, error) {
	var rm Roadmap
	var focusRaw []byte
	err := row.Scan(&rm.ID, &rm.UserID, &rm.OrgID, &rm.Title, &rm.Mode, &rm.Status, &rm.IsPublic, &rm.GoalDescription,
		&rm.TargetRole, &rm.SkillLevel, &rm.TimeframeWeeks, &focusRaw, &rm.GenerationError,
		&rm.GeneratedAt, &rm.CreatedAt, &rm.UpdatedAt)
	if err != nil {
		return Roadmap{}, err
	}
	rm.FocusAreas = []string{}
	if len(focusRaw) > 0 {
		if err := json.Unmarshal(focusRaw, &rm.FocusAreas); err != nil {
			return Roadmap{}, fmt.Errorf("roadmap: unmarshal focus_areas: %w", err)
		}
	}
	return rm, nil
}

// GetForUser fetches a roadmap owned by userID, including its full nested
// phase -> milestone -> module tree ordered by position.
func (r *Repo) GetForUser(ctx context.Context, id, userID string) (Roadmap, error) {
	rm, err := scanRoadmap(r.pool.QueryRow(ctx,
		`SELECT `+roadmapColumns+` FROM roadmaps WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
		id, userID,
	))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Roadmap{}, ErrNotFound
		}
		return Roadmap{}, fmt.Errorf("roadmap: get: %w", err)
	}

	phases, err := r.getTree(ctx, id)
	if err != nil {
		return Roadmap{}, err
	}
	rm.Phases = phases
	for _, p := range phases {
		for _, m := range p.Milestones {
			rm.ModuleCount += len(m.Modules)
			for _, mod := range m.Modules {
				if mod.CompletedAt != nil {
					rm.CompletedCount++
				}
			}
		}
	}
	return rm, nil
}

// GetPublicWithTree fetches a roadmap that its owner has marked public, with
// no ownership check — used by the "start this roadmap" fork flow, which any
// authenticated user can trigger on any public, generated roadmap.
func (r *Repo) GetPublicWithTree(ctx context.Context, id string) (Roadmap, error) {
	rm, err := scanRoadmap(r.pool.QueryRow(ctx,
		`SELECT `+roadmapColumns+` FROM roadmaps
		 WHERE id = $1 AND is_public AND status IN ($2, $3) AND deleted_at IS NULL`,
		id, StatusActive, StatusCompleted,
	))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Roadmap{}, ErrNotFound
		}
		return Roadmap{}, fmt.Errorf("roadmap: get public: %w", err)
	}
	phases, err := r.getTree(ctx, id)
	if err != nil {
		return Roadmap{}, err
	}
	rm.Phases = phases
	return rm, nil
}

// getTree loads every phase/milestone/module for a roadmap in three flat
// queries and assembles them in memory — simpler and cheaper than a
// recursive/joined query for the depth-3 tree this always is.
func (r *Repo) getTree(ctx context.Context, roadmapID string) ([]Phase, error) {
	phaseRows, err := r.pool.Query(ctx,
		`SELECT id, roadmap_id, title, description, position, estimated_weeks
		 FROM roadmap_phases WHERE roadmap_id = $1 ORDER BY position`, roadmapID)
	if err != nil {
		return nil, fmt.Errorf("roadmap: get phases: %w", err)
	}
	phases := []Phase{}
	phaseIdx := map[string]int{}
	for phaseRows.Next() {
		var p Phase
		if err := phaseRows.Scan(&p.ID, &p.RoadmapID, &p.Title, &p.Description, &p.Position, &p.EstimatedWeeks); err != nil {
			phaseRows.Close()
			return nil, fmt.Errorf("roadmap: scan phase: %w", err)
		}
		p.Milestones = []Milestone{}
		phaseIdx[p.ID] = len(phases)
		phases = append(phases, p)
	}
	phaseRows.Close()
	if err := phaseRows.Err(); err != nil {
		return nil, fmt.Errorf("roadmap: iterate phases: %w", err)
	}
	if len(phases) == 0 {
		return phases, nil
	}

	milestoneRows, err := r.pool.Query(ctx,
		`SELECT m.id, m.phase_id, m.title, m.description, m.position, m.estimated_hours
		 FROM roadmap_milestones m
		 JOIN roadmap_phases p ON p.id = m.phase_id
		 WHERE p.roadmap_id = $1 ORDER BY m.position`, roadmapID)
	if err != nil {
		return nil, fmt.Errorf("roadmap: get milestones: %w", err)
	}
	milestoneIdx := map[string]int{}
	milestoneOwner := map[string]string{} // milestoneID -> phaseID
	for milestoneRows.Next() {
		var m Milestone
		if err := milestoneRows.Scan(&m.ID, &m.PhaseID, &m.Title, &m.Description, &m.Position, &m.EstimatedHours); err != nil {
			milestoneRows.Close()
			return nil, fmt.Errorf("roadmap: scan milestone: %w", err)
		}
		m.Modules = []Module{}
		pi, ok := phaseIdx[m.PhaseID]
		if !ok {
			continue
		}
		milestoneOwner[m.ID] = m.PhaseID
		milestoneIdx[m.ID] = len(phases[pi].Milestones)
		phases[pi].Milestones = append(phases[pi].Milestones, m)
	}
	milestoneRows.Close()
	if err := milestoneRows.Err(); err != nil {
		return nil, fmt.Errorf("roadmap: iterate milestones: %w", err)
	}

	// Resource title/slug are resolved here via LEFT JOIN rather than stored on
	// roadmap_modules — resource_type is polymorphic (course|lab|question), so
	// exactly one of the three joins matches per row, and COALESCE picks it.
	// This keeps the display title always current instead of a stale copy.
	moduleRows, err := r.pool.Query(ctx,
		`SELECT mo.id, mo.milestone_id, mo.title, mo.description, mo.position, mo.module_type,
		        mo.resource_type, mo.resource_id, mo.estimated_minutes, mo.completed_at,
		        COALESCE(rc.title, rl.title, rq.title), rc.slug
		 FROM roadmap_modules mo
		 JOIN roadmap_milestones m ON m.id = mo.milestone_id
		 JOIN roadmap_phases p ON p.id = m.phase_id
		 LEFT JOIN courses rc ON mo.resource_type = 'course' AND mo.resource_id = rc.id
		 LEFT JOIN lab_definitions rl ON mo.resource_type = 'lab' AND mo.resource_id = rl.id
		 LEFT JOIN questions rq ON mo.resource_type = 'question' AND mo.resource_id = rq.id
		 WHERE p.roadmap_id = $1 ORDER BY mo.position`, roadmapID)
	if err != nil {
		return nil, fmt.Errorf("roadmap: get modules: %w", err)
	}
	defer moduleRows.Close()
	for moduleRows.Next() {
		var mod Module
		if err := moduleRows.Scan(&mod.ID, &mod.MilestoneID, &mod.Title, &mod.Description, &mod.Position,
			&mod.ModuleType, &mod.ResourceType, &mod.ResourceID, &mod.EstimatedMinutes, &mod.CompletedAt,
			&mod.ResourceTitle, &mod.ResourceSlug); err != nil {
			return nil, fmt.Errorf("roadmap: scan module: %w", err)
		}
		phaseID, ok := milestoneOwner[mod.MilestoneID]
		if !ok {
			continue
		}
		pi := phaseIdx[phaseID]
		mi := milestoneIdx[mod.MilestoneID]
		phases[pi].Milestones[mi].Modules = append(phases[pi].Milestones[mi].Modules, mod)
	}
	if err := moduleRows.Err(); err != nil {
		return nil, fmt.Errorf("roadmap: iterate modules: %w", err)
	}
	return phases, nil
}

// listWithCounts runs a roadmaps query (any WHERE/ORDER/LIMIT clause) with
// module/completed counts attached for the list-view progress bar, without
// the full nested tree. Shared by ListForUser and ListPublic so the counts
// subqueries exist in exactly one place.
func (r *Repo) listWithCounts(ctx context.Context, whereOrderLimit string, args ...any) ([]Roadmap, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+roadmapColumns+`,
		        COALESCE((SELECT COUNT(*) FROM roadmap_modules mo
		                  JOIN roadmap_milestones m ON m.id = mo.milestone_id
		                  JOIN roadmap_phases p ON p.id = m.phase_id
		                  WHERE p.roadmap_id = roadmaps.id), 0) AS module_count,
		        COALESCE((SELECT COUNT(*) FROM roadmap_modules mo
		                  JOIN roadmap_milestones m ON m.id = mo.milestone_id
		                  JOIN roadmap_phases p ON p.id = m.phase_id
		                  WHERE p.roadmap_id = roadmaps.id AND mo.completed_at IS NOT NULL), 0) AS completed_count
		 FROM roadmaps `+whereOrderLimit,
		args...)
	if err != nil {
		return nil, fmt.Errorf("roadmap: list: %w", err)
	}
	defer rows.Close()

	out := []Roadmap{}
	for rows.Next() {
		var rm Roadmap
		var focusRaw []byte
		if err := rows.Scan(&rm.ID, &rm.UserID, &rm.OrgID, &rm.Title, &rm.Mode, &rm.Status, &rm.IsPublic, &rm.GoalDescription,
			&rm.TargetRole, &rm.SkillLevel, &rm.TimeframeWeeks, &focusRaw, &rm.GenerationError,
			&rm.GeneratedAt, &rm.CreatedAt, &rm.UpdatedAt, &rm.ModuleCount, &rm.CompletedCount); err != nil {
			return nil, fmt.Errorf("roadmap: scan list row: %w", err)
		}
		rm.FocusAreas = []string{}
		if len(focusRaw) > 0 {
			if err := json.Unmarshal(focusRaw, &rm.FocusAreas); err != nil {
				return nil, fmt.Errorf("roadmap: unmarshal focus_areas: %w", err)
			}
		}
		out = append(out, rm)
	}
	return out, rows.Err()
}

// ListForUser returns the user's non-deleted roadmaps, most recent first.
func (r *Repo) ListForUser(ctx context.Context, userID string) ([]Roadmap, error) {
	return r.listWithCounts(ctx, `WHERE user_id = $1 AND deleted_at IS NULL ORDER BY created_at DESC`, userID)
}

// ListPublic returns roadmaps their owners have marked public, most recent
// first, capped at 50 — a browse gallery, not a paginated catalog.
func (r *Repo) ListPublic(ctx context.Context) ([]Roadmap, error) {
	return r.listWithCounts(ctx,
		`WHERE is_public AND status IN ($1, $2) AND deleted_at IS NULL ORDER BY created_at DESC LIMIT 50`,
		StatusActive, StatusCompleted)
}

// GetByID fetches a roadmap without an ownership filter — used only by the
// async job handler, which enforces tenant isolation via job.OrgID instead.
func (r *Repo) GetByID(ctx context.Context, id string) (Roadmap, error) {
	rm, err := scanRoadmap(r.pool.QueryRow(ctx,
		`SELECT `+roadmapColumns+` FROM roadmaps WHERE id = $1 AND deleted_at IS NULL`, id,
	))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Roadmap{}, ErrNotFound
		}
		return Roadmap{}, fmt.Errorf("roadmap: get by id: %w", err)
	}
	return rm, nil
}

// SetGenerating flips a roadmap back to status=generating for a regenerate
// run. Returns ErrAlreadyGenerating if it's already in that state.
func (r *Repo) SetGenerating(ctx context.Context, id, userID string) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE roadmaps SET status = $1, updated_at = now()
		 WHERE id = $2 AND user_id = $3 AND deleted_at IS NULL AND status <> $1`,
		StatusGenerating, id, userID)
	if err != nil {
		return fmt.Errorf("roadmap: set generating: %w", err)
	}
	if tag.RowsAffected() == 0 {
		// Either not found/not owned, or already generating — disambiguate.
		var status string
		err := r.pool.QueryRow(ctx,
			`SELECT status FROM roadmaps WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`, id, userID,
		).Scan(&status)
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotFound
		}
		if err != nil {
			return fmt.Errorf("roadmap: set generating: check status: %w", err)
		}
		return ErrAlreadyGenerating
	}
	return nil
}

// ReplaceGeneratedTree deletes any existing phases (cascading to milestones
// and modules) and inserts the freshly generated + catalog-matched tree, then
// flips the roadmap to active. Delete+reinsert makes this naturally safe to
// re-run (job retries, regenerate) without a separate idempotency check.
func (r *Repo) ReplaceGeneratedTree(ctx context.Context, roadmapID string, phases []Phase) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("roadmap: begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if _, err := tx.Exec(ctx, `DELETE FROM roadmap_phases WHERE roadmap_id = $1`, roadmapID); err != nil {
		return fmt.Errorf("roadmap: delete existing phases: %w", err)
	}

	for _, p := range phases {
		var phaseID string
		if err := tx.QueryRow(ctx,
			`INSERT INTO roadmap_phases (roadmap_id, title, description, position, estimated_weeks)
			 VALUES ($1, $2, $3, $4, $5) RETURNING id`,
			roadmapID, p.Title, p.Description, p.Position, p.EstimatedWeeks,
		).Scan(&phaseID); err != nil {
			return fmt.Errorf("roadmap: insert phase %d: %w", p.Position, err)
		}

		for _, m := range p.Milestones {
			var milestoneID string
			if err := tx.QueryRow(ctx,
				`INSERT INTO roadmap_milestones (phase_id, title, description, position, estimated_hours)
				 VALUES ($1, $2, $3, $4, $5) RETURNING id`,
				phaseID, m.Title, m.Description, m.Position, m.EstimatedHours,
			).Scan(&milestoneID); err != nil {
				return fmt.Errorf("roadmap: insert milestone %d in phase %d: %w", m.Position, p.Position, err)
			}

			for _, mod := range m.Modules {
				if _, err := tx.Exec(ctx,
					`INSERT INTO roadmap_modules
					   (milestone_id, title, description, position, module_type, resource_type, resource_id, estimated_minutes)
					 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
					milestoneID, mod.Title, mod.Description, mod.Position, mod.ModuleType,
					mod.ResourceType, mod.ResourceID, mod.EstimatedMinutes,
				); err != nil {
					return fmt.Errorf("roadmap: insert module %d in milestone %d: %w", mod.Position, m.Position, err)
				}
			}
		}
	}

	if _, err := tx.Exec(ctx,
		`UPDATE roadmaps SET status = $1, generated_at = now(), generation_error = NULL, updated_at = now() WHERE id = $2`,
		StatusActive, roadmapID,
	); err != nil {
		return fmt.Errorf("roadmap: activate: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("roadmap: commit tx: %w", err)
	}
	return nil
}

// MarkFailed records a generation failure so the frontend can show it and
// offer a retry, instead of leaving the roadmap stuck in 'generating'.
func (r *Repo) MarkFailed(ctx context.Context, roadmapID, reason string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE roadmaps SET status = $1, generation_error = $2, updated_at = now() WHERE id = $3`,
		StatusFailed, reason, roadmapID)
	if err != nil {
		return fmt.Errorf("roadmap: mark failed: %w", err)
	}
	return nil
}

// UpdateModuleProgress toggles a module's completed_at, verifying the module
// belongs to a roadmap owned by userID via the milestone/phase join.
func (r *Repo) UpdateModuleProgress(ctx context.Context, roadmapID, moduleID, userID string, completed bool) error {
	var completedAtExpr string
	if completed {
		completedAtExpr = "now()"
	} else {
		completedAtExpr = "NULL"
	}
	tag, err := r.pool.Exec(ctx,
		`UPDATE roadmap_modules mo
		 SET completed_at = `+completedAtExpr+`
		 FROM roadmap_milestones m, roadmap_phases p, roadmaps r
		 WHERE mo.id = $1
		   AND mo.milestone_id = m.id AND m.phase_id = p.id AND p.roadmap_id = r.id
		   AND r.id = $2 AND r.user_id = $3 AND r.deleted_at IS NULL`,
		moduleID, roadmapID, userID)
	if err != nil {
		return fmt.Errorf("roadmap: update module progress: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// UpdateModule renames/redescribes a module (DEFINED-mode light edit) and
// flips the parent roadmap's mode to 'defined'.
func (r *Repo) UpdateModule(ctx context.Context, roadmapID, moduleID, userID string, title, description *string) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("roadmap: begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	tag, err := tx.Exec(ctx,
		`UPDATE roadmap_modules mo
		 SET title = COALESCE($1, mo.title), description = COALESCE($2, mo.description)
		 FROM roadmap_milestones m, roadmap_phases p, roadmaps r
		 WHERE mo.id = $3
		   AND mo.milestone_id = m.id AND m.phase_id = p.id AND p.roadmap_id = r.id
		   AND r.id = $4 AND r.user_id = $5 AND r.deleted_at IS NULL`,
		title, description, moduleID, roadmapID, userID)
	if err != nil {
		return fmt.Errorf("roadmap: update module: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}

	if _, err := tx.Exec(ctx,
		`UPDATE roadmaps SET mode = $1, updated_at = now() WHERE id = $2 AND user_id = $3`,
		ModeDefined, roadmapID, userID,
	); err != nil {
		return fmt.Errorf("roadmap: flip mode to defined: %w", err)
	}

	return tx.Commit(ctx)
}

// DeleteModule removes a single module (DEFINED-mode light edit).
func (r *Repo) DeleteModule(ctx context.Context, roadmapID, moduleID, userID string) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("roadmap: begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	tag, err := tx.Exec(ctx,
		`DELETE FROM roadmap_modules mo
		 USING roadmap_milestones m, roadmap_phases p, roadmaps r
		 WHERE mo.id = $1
		   AND mo.milestone_id = m.id AND m.phase_id = p.id AND p.roadmap_id = r.id
		   AND r.id = $2 AND r.user_id = $3 AND r.deleted_at IS NULL`,
		moduleID, roadmapID, userID)
	if err != nil {
		return fmt.Errorf("roadmap: delete module: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}

	if _, err := tx.Exec(ctx,
		`UPDATE roadmaps SET mode = $1, updated_at = now() WHERE id = $2 AND user_id = $3`,
		ModeDefined, roadmapID, userID,
	); err != nil {
		return fmt.Errorf("roadmap: flip mode to defined: %w", err)
	}

	return tx.Commit(ctx)
}

// UpdateRoadmap renames and/or changes status (archive/reactivate) and/or
// flips is_public. Marking a still-generating roadmap public is harmless —
// ListPublic/GetPublicWithTree only surface active/completed roadmaps, so it
// simply won't appear until generation finishes.
func (r *Repo) UpdateRoadmap(ctx context.Context, id, userID string, title, status *string, isPublic *bool) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE roadmaps
		 SET title = COALESCE($1, title), status = COALESCE($2, status),
		     is_public = COALESCE($3, is_public), updated_at = now()
		 WHERE id = $4 AND user_id = $5 AND deleted_at IS NULL`,
		title, status, isPublic, id, userID)
	if err != nil {
		return fmt.Errorf("roadmap: update: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// SoftDelete hides a roadmap from the user without destroying history.
func (r *Repo) SoftDelete(ctx context.Context, id, userID string) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE roadmaps SET deleted_at = now(), updated_at = now()
		 WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
		id, userID)
	if err != nil {
		return fmt.Errorf("roadmap: soft delete: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
