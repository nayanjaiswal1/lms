package roadmap

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

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

// getTree loads the nested phase/milestone/module tree from the structure JSONB,
// then resolves resource titles/slugs via LEFT JOINs against the catalog tables.
func (r *Repo) getTree(ctx context.Context, roadmapID string) ([]Phase, error) {
	var structureRaw []byte
	err := r.pool.QueryRow(ctx,
		`SELECT structure FROM roadmaps WHERE id = $1`, roadmapID,
	).Scan(&structureRaw)
	if err != nil {
		return nil, fmt.Errorf("roadmap: get structure: %w", err)
	}

	// Parse the JSONB structure into phases/milestones/modules
	type structureJSON struct {
		Phases []struct {
			ID             string `json:"id"`
			Title          string `json:"title"`
			Description    *string `json:"description"`
			Position       int    `json:"position"`
			EstimatedWeeks *int   `json:"estimated_weeks"`
			Milestones     []struct {
				ID             string `json:"id"`
				Title          string `json:"title"`
				Description    *string `json:"description"`
				Position       int    `json:"position"`
				EstimatedHours *int   `json:"estimated_hours"`
				Modules        []struct {
					ID               string `json:"id"`
					Title            string `json:"title"`
					Description      *string `json:"description"`
					Position         int    `json:"position"`
					Type             string `json:"type"`
					ResourceType     *string `json:"resource_type"`
					ResourceID       *string `json:"resource_id"`
					EstimatedMinutes *int   `json:"estimated_minutes"`
				} `json:"modules"`
			} `json:"milestones"`
		} `json:"phases"`
	}

	var s structureJSON
	if len(structureRaw) > 0 {
		if err := json.Unmarshal(structureRaw, &s); err != nil {
			return nil, fmt.Errorf("roadmap: unmarshal structure: %w", err)
		}
	}

	// Collect all module IDs to fetch completion status in one query
	var moduleKeys []string
	for _, p := range s.Phases {
		for _, m := range p.Milestones {
			for _, mod := range m.Modules {
				moduleKeys = append(moduleKeys, mod.ID)
			}
		}
	}

	// Fetch completion status for all modules from roadmap_module_progress
	progressMap := make(map[string]*time.Time)
	if len(moduleKeys) > 0 {
		progressRows, err := r.pool.Query(ctx,
			`SELECT module_key, completed_at FROM roadmap_module_progress
			 WHERE roadmap_id = $1 AND module_key = ANY($2)`,
			roadmapID, moduleKeys)
		if err != nil {
			return nil, fmt.Errorf("roadmap: get module progress: %w", err)
		}
		defer progressRows.Close()
		for progressRows.Next() {
			var key string
			var completedAt *time.Time
			if err := progressRows.Scan(&key, &completedAt); err != nil {
				return nil, fmt.Errorf("roadmap: scan progress: %w", err)
			}
			progressMap[key] = completedAt
		}
		if err := progressRows.Err(); err != nil {
			return nil, fmt.Errorf("roadmap: iterate progress: %w", err)
		}
	}

	// Resolve resource titles/slugs for all resources in one query
	resourceMap := make(map[string]struct{ title *string; slug *string })
	if len(moduleKeys) > 0 {
		// Extract all (resource_type, resource_id) pairs from the structure
		type resource struct {
			rType string
			rID   string
		}
		resourceSet := make(map[string]resource)
		for _, p := range s.Phases {
			for _, m := range p.Milestones {
				for _, mod := range m.Modules {
					if mod.ResourceType != nil && mod.ResourceID != nil {
						resKey := *mod.ResourceType + ":" + *mod.ResourceID
						resourceSet[resKey] = resource{rType: *mod.ResourceType, rID: *mod.ResourceID}
					}
				}
			}
		}

		// Query each resource type
		if len(resourceSet) > 0 {
			// Courses
			courseIDs := []string{}
			for _, res := range resourceSet {
				if res.rType == "course" {
					courseIDs = append(courseIDs, res.rID)
				}
			}
			if len(courseIDs) > 0 {
				courseRows, err := r.pool.Query(ctx,
					`SELECT id, title, slug FROM courses WHERE id = ANY($1)`, courseIDs)
				if err != nil {
					return nil, fmt.Errorf("roadmap: get courses: %w", err)
				}
				for courseRows.Next() {
					var id, title, slug string
					if err := courseRows.Scan(&id, &title, &slug); err != nil {
						courseRows.Close()
						return nil, fmt.Errorf("roadmap: scan course: %w", err)
					}
					resourceMap["course:"+id] = struct{ title *string; slug *string }{
						title: &title, slug: &slug,
					}
				}
				courseRows.Close()
			}

			// Labs
			labIDs := []string{}
			for _, res := range resourceSet {
				if res.rType == "lab" {
					labIDs = append(labIDs, res.rID)
				}
			}
			if len(labIDs) > 0 {
				labRows, err := r.pool.Query(ctx,
					`SELECT id, title FROM lab_definitions WHERE id = ANY($1)`, labIDs)
				if err != nil {
					return nil, fmt.Errorf("roadmap: get labs: %w", err)
				}
				for labRows.Next() {
					var id, title string
					if err := labRows.Scan(&id, &title); err != nil {
						labRows.Close()
						return nil, fmt.Errorf("roadmap: scan lab: %w", err)
					}
					resourceMap["lab:"+id] = struct{ title *string; slug *string }{
						title: &title, slug: nil,
					}
				}
				labRows.Close()
			}

			// Questions
			questionIDs := []string{}
			for _, res := range resourceSet {
				if res.rType == "question" {
					questionIDs = append(questionIDs, res.rID)
				}
			}
			if len(questionIDs) > 0 {
				questionRows, err := r.pool.Query(ctx,
					`SELECT id, title FROM questions WHERE id = ANY($1)`, questionIDs)
				if err != nil {
					return nil, fmt.Errorf("roadmap: get questions: %w", err)
				}
				for questionRows.Next() {
					var id, title string
					if err := questionRows.Scan(&id, &title); err != nil {
						questionRows.Close()
						return nil, fmt.Errorf("roadmap: scan question: %w", err)
					}
					resourceMap["question:"+id] = struct{ title *string; slug *string }{
						title: &title, slug: nil,
					}
				}
				questionRows.Close()
			}
		}
	}

	// Reconstruct the phases/milestones/modules tree with resolved data
	phases := []Phase{}
	for _, sp := range s.Phases {
		p := Phase{
			ID:             sp.ID,
			RoadmapID:      roadmapID,
			Title:          sp.Title,
			Description:    sp.Description,
			Position:       sp.Position,
			EstimatedWeeks: sp.EstimatedWeeks,
			Milestones:     []Milestone{},
		}
		for _, sm := range sp.Milestones {
			m := Milestone{
				ID:             sm.ID,
				PhaseID:        sp.ID,
				Title:          sm.Title,
				Description:    sm.Description,
				Position:       sm.Position,
				EstimatedHours: sm.EstimatedHours,
				Modules:        []Module{},
			}
			for _, smod := range sm.Modules {
				mod := Module{
					ID:               smod.ID,
					MilestoneID:      sm.ID,
					Title:            smod.Title,
					Description:      smod.Description,
					Position:         smod.Position,
					ModuleType:       smod.Type,
					ResourceType:     smod.ResourceType,
					ResourceID:       smod.ResourceID,
					EstimatedMinutes: smod.EstimatedMinutes,
					CompletedAt:      progressMap[smod.ID],
				}
				// Resolve resource title/slug
				if smod.ResourceType != nil && smod.ResourceID != nil {
					key := *smod.ResourceType + ":" + *smod.ResourceID
					if res, ok := resourceMap[key]; ok {
						mod.ResourceTitle = res.title
						mod.ResourceSlug = res.slug
					}
				}
				m.Modules = append(m.Modules, mod)
			}
			p.Milestones = append(p.Milestones, m)
		}
		phases = append(phases, p)
	}
	return phases, nil
}

// listWithCounts runs a roadmaps query (any WHERE/ORDER/LIMIT clause) with
// module/completed counts attached for the list-view progress bar, without
// the full nested tree. Counts are computed from the structure JSONB and progress table.
func (r *Repo) listWithCounts(ctx context.Context, whereOrderLimit string, args ...any) ([]Roadmap, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+roadmapColumns+`
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
			&rm.GeneratedAt, &rm.CreatedAt, &rm.UpdatedAt); err != nil {
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
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("roadmap: iterate list: %w", err)
	}

	// For each roadmap, compute module counts from structure JSONB
	for i := range out {
		phases, err := r.getTree(ctx, out[i].ID)
		if err != nil {
			return nil, err
		}
		for _, p := range phases {
			for _, m := range p.Milestones {
				out[i].ModuleCount += len(m.Modules)
				for _, mod := range m.Modules {
					if mod.CompletedAt != nil {
						out[i].CompletedCount++
					}
				}
			}
		}
	}
	return out, nil
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

// ReplaceGeneratedTree serializes the tree into structure JSONB, updates the
// roadmap, and flips it to active. Delete+reinsert makes this naturally safe
// to re-run (job retries, regenerate) without a separate idempotency check.
func (r *Repo) ReplaceGeneratedTree(ctx context.Context, roadmapID string, phases []Phase) error {
	// Serialize the tree into the JSONB structure
	type structureModule struct {
		ID               string  `json:"id"`
		Title            string  `json:"title"`
		Description      *string `json:"description"`
		Position         int     `json:"position"`
		Type             string  `json:"type"`
		ResourceType     *string `json:"resource_type"`
		ResourceID       *string `json:"resource_id"`
		EstimatedMinutes *int    `json:"estimated_minutes"`
	}
	type structureMilestone struct {
		ID             string             `json:"id"`
		Title          string             `json:"title"`
		Description    *string            `json:"description"`
		Position       int                `json:"position"`
		EstimatedHours *int               `json:"estimated_hours"`
		Modules        []structureModule  `json:"modules"`
	}
	type structurePhase struct {
		ID             string                 `json:"id"`
		Title          string                 `json:"title"`
		Description    *string                `json:"description"`
		Position       int                    `json:"position"`
		EstimatedWeeks *int                   `json:"estimated_weeks"`
		Milestones     []structureMilestone   `json:"milestones"`
	}
	type structureJSON struct {
		Phases []structurePhase `json:"phases"`
	}

	s := structureJSON{Phases: []structurePhase{}}
	for _, p := range phases {
		sp := structurePhase{
			ID:             p.ID,
			Title:          p.Title,
			Description:    p.Description,
			Position:       p.Position,
			EstimatedWeeks: p.EstimatedWeeks,
			Milestones:     []structureMilestone{},
		}
		for _, m := range p.Milestones {
			sm := structureMilestone{
				ID:             m.ID,
				Title:          m.Title,
				Description:    m.Description,
				Position:       m.Position,
				EstimatedHours: m.EstimatedHours,
				Modules:        []structureModule{},
			}
			for _, mod := range m.Modules {
				smod := structureModule{
					ID:               mod.ID,
					Title:            mod.Title,
					Description:      mod.Description,
					Position:         mod.Position,
					Type:             mod.ModuleType,
					ResourceType:     mod.ResourceType,
					ResourceID:       mod.ResourceID,
					EstimatedMinutes: mod.EstimatedMinutes,
				}
				sm.Modules = append(sm.Modules, smod)
			}
			sp.Milestones = append(sp.Milestones, sm)
		}
		s.Phases = append(s.Phases, sp)
	}

	structureRaw, err := json.Marshal(s)
	if err != nil {
		return fmt.Errorf("roadmap: marshal structure: %w", err)
	}

	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("roadmap: begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// Clear existing progress entries
	if _, err := tx.Exec(ctx, `DELETE FROM roadmap_module_progress WHERE roadmap_id = $1`, roadmapID); err != nil {
		return fmt.Errorf("roadmap: delete existing progress: %w", err)
	}

	// Update the structure JSONB and flip to active
	if _, err := tx.Exec(ctx,
		`UPDATE roadmaps SET structure = $1, status = $2, generated_at = now(), generation_error = NULL, updated_at = now() WHERE id = $3`,
		structureRaw, StatusActive, roadmapID,
	); err != nil {
		return fmt.Errorf("roadmap: update roadmap: %w", err)
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

// UpdateModuleProgress toggles a module's completion in roadmap_module_progress,
// verifying the roadmap is owned by userID.
func (r *Repo) UpdateModuleProgress(ctx context.Context, roadmapID, moduleID, userID string, completed bool) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("roadmap: begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// Verify ownership
	var exists bool
	err = tx.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM roadmaps WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL)`,
		roadmapID, userID,
	).Scan(&exists)
	if err != nil {
		return fmt.Errorf("roadmap: verify ownership: %w", err)
	}
	if !exists {
		return ErrNotFound
	}

	if completed {
		// Insert or update the progress record
		_, err = tx.Exec(ctx,
			`INSERT INTO roadmap_module_progress (roadmap_id, module_key, completed_at)
			 VALUES ($1, $2, now())
			 ON CONFLICT (roadmap_id, module_key) DO UPDATE SET completed_at = now()`,
			roadmapID, moduleID)
	} else {
		// Remove the progress record (mark as incomplete)
		_, err = tx.Exec(ctx,
			`DELETE FROM roadmap_module_progress WHERE roadmap_id = $1 AND module_key = $2`,
			roadmapID, moduleID)
	}
	if err != nil {
		return fmt.Errorf("roadmap: update module progress: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("roadmap: commit tx: %w", err)
	}
	return nil
}

// UpdateModule renames/redescribes a module in the structure JSONB (DEFINED-mode light edit)
// and flips the parent roadmap's mode to 'defined'.
func (r *Repo) UpdateModule(ctx context.Context, roadmapID, moduleID, userID string, title, description *string) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("roadmap: begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// Fetch current structure
	var structureRaw []byte
	err = tx.QueryRow(ctx,
		`SELECT structure FROM roadmaps WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
		roadmapID, userID,
	).Scan(&structureRaw)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotFound
		}
		return fmt.Errorf("roadmap: get structure: %w", err)
	}

	// Parse and update the structure
	var data map[string]interface{}
	if len(structureRaw) > 0 {
		if err := json.Unmarshal(structureRaw, &data); err != nil {
			return fmt.Errorf("roadmap: unmarshal structure: %w", err)
		}
	}
	if data == nil {
		data = make(map[string]interface{})
	}

	// Generic map-based search and update
	phases, ok := data["phases"].([]interface{})
	found := false
	if ok {
		for _, p := range phases {
			phase, ok := p.(map[string]interface{})
			if !ok {
				continue
			}
			milestones, ok := phase["milestones"].([]interface{})
			if !ok {
				continue
			}
			for _, m := range milestones {
				milestone, ok := m.(map[string]interface{})
				if !ok {
					continue
				}
				modules, ok := milestone["modules"].([]interface{})
				if !ok {
					continue
				}
				for _, mod := range modules {
					module, ok := mod.(map[string]interface{})
					if !ok {
						continue
					}
					if id, ok := module["id"].(string); ok && id == moduleID {
						if title != nil {
							module["title"] = *title
						}
						if description != nil {
							module["description"] = *description
						}
						found = true
						break
					}
				}
			}
		}
	}
	if !found {
		return ErrNotFound
	}

	// Serialize and update
	newStructureRaw, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("roadmap: marshal structure: %w", err)
	}

	if _, err := tx.Exec(ctx,
		`UPDATE roadmaps SET structure = $1, mode = $2, updated_at = now() WHERE id = $3`,
		newStructureRaw, ModeDefined, roadmapID,
	); err != nil {
		return fmt.Errorf("roadmap: update roadmap: %w", err)
	}

	return tx.Commit(ctx)
}

// DeleteModule removes a single module from the structure JSONB (DEFINED-mode light edit).
func (r *Repo) DeleteModule(ctx context.Context, roadmapID, moduleID, userID string) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("roadmap: begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// Fetch current structure
	var structureRaw []byte
	err = tx.QueryRow(ctx,
		`SELECT structure FROM roadmaps WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
		roadmapID, userID,
	).Scan(&structureRaw)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotFound
		}
		return fmt.Errorf("roadmap: get structure: %w", err)
	}

	// Parse and update the structure
	var data map[string]interface{}
	if len(structureRaw) > 0 {
		if err := json.Unmarshal(structureRaw, &data); err != nil {
			return fmt.Errorf("roadmap: unmarshal structure: %w", err)
		}
	}
	if data == nil {
		data = make(map[string]interface{})
	}

	// Generic map-based search and delete
	phases, ok := data["phases"].([]interface{})
	found := false
	if ok {
		for _, p := range phases {
			phase, ok := p.(map[string]interface{})
			if !ok {
				continue
			}
			milestones, ok := phase["milestones"].([]interface{})
			if !ok {
				continue
			}
			for _, m := range milestones {
				milestone, ok := m.(map[string]interface{})
				if !ok {
					continue
				}
				modules, ok := milestone["modules"].([]interface{})
				if !ok {
					continue
				}
				// Filter out the matching module
				newModules := []interface{}{}
				for _, mod := range modules {
					module, ok := mod.(map[string]interface{})
					if !ok {
						newModules = append(newModules, mod)
						continue
					}
					if id, ok := module["id"].(string); ok && id == moduleID {
						found = true
						continue // skip this module (delete it)
					}
					newModules = append(newModules, mod)
				}
				milestone["modules"] = newModules
			}
		}
	}
	if !found {
		return ErrNotFound
	}

	// Serialize and update
	newStructureRaw, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("roadmap: marshal structure: %w", err)
	}

	if _, err := tx.Exec(ctx,
		`UPDATE roadmaps SET structure = $1, mode = $2, updated_at = now() WHERE id = $3`,
		newStructureRaw, ModeDefined, roadmapID,
	); err != nil {
		return fmt.Errorf("roadmap: update roadmap: %w", err)
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
