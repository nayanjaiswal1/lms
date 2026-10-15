package labbuild

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"sort"

	"github.com/jackc/pgx/v5"
	"github.com/mindforge/backend/internal/contentpipeline/canonical"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/labauthor"
	"github.com/mindforge/backend/internal/labblock"
	"github.com/mindforge/backend/internal/labkinds"
	"github.com/mindforge/backend/internal/labs"
	"github.com/mindforge/backend/internal/library"
)

const (
	// defaultMaxDurationMinutes is a published debug lab's session budget
	// (docs/debug-labs.md B4/§2: 90 minutes, org cap permitting).
	defaultMaxDurationMinutes = 90
	previewLabSuffix          = "preview_lab"
	previewTitlePrefix        = "[Preview] "
	visibilityPreview         = "private"
	visibilityPublished       = "org"
)

// PublishReq places a published lab in a course section.
type PublishReq struct {
	CourseID   string `json:"course_id"`
	SectionID  string `json:"section_id"`
	Position   *int   `json:"position"`
	IsRequired bool   `json:"is_required"`
}

func (p PublishReq) placed() bool { return p.SectionID != "" }

// PublishResult is what a publish returns.
type PublishResult struct {
	LabID         string                `json:"lab_id"`
	TaskVersionID string                `json:"task_version_id"`
	Version       int                   `json:"version"`
	Republished   bool                  `json:"republished"`
	Unchanged     bool                  `json:"unchanged"`
	Module        *courses.CourseModule `json:"module,omitempty"`
}

// publishIn parameterises the single lab-versioning path shared by publish and
// the instructor preview.
type publishIn struct {
	OrgID, UserID string
	Build         *Build
	Kind          labkinds.Kind
	LabID         string // existing lab, or the deterministic preview id; "" = create a new lab
	Title         string
	Preview       bool
	RecipeID      string
	Catalog       *catalogMeta // nil for previews
}

type catalogMeta struct {
	Stack, Category, Difficulty string
	Skills                      []string
}

type publishOut struct {
	LabID, VersionID string
	Version          int
	Created          bool
	Unchanged        bool
}

// publishLab creates or updates the lab row, syncs its live tasks, cuts a new
// immutable task version tied to the build (unless this exact build is already
// the published one), and publishes it - all inside the caller's transaction.
// In-flight sessions are pinned to their task version and that version's build,
// so nothing here can change a running session.
func (s *Service) publishLab(ctx context.Context, tx pgx.Tx, in publishIn) (*publishOut, error) {
	variants, err := s.repo.ListVariants(ctx, in.Build.ID)
	if err != nil {
		return nil, fmt.Errorf("labbuild.publishLab: %w", err)
	}
	previewPort := 0
	if len(variants) > 0 && len(variants[0].AppPorts) > 0 {
		previewPort = variants[0].AppPorts[0]
	}
	kind := in.Kind
	out := &publishOut{}

	// 1. The lab row (locked, org-checked).
	labID := in.LabID
	visibility := visibilityPublished
	if in.Preview {
		visibility = visibilityPreview
	}
	if labID != "" {
		var orgID string
		err := tx.QueryRow(ctx, `SELECT org_id FROM public.lab_definitions WHERE id = $1 FOR UPDATE`, labID).Scan(&orgID)
		switch {
		case errors.Is(err, pgx.ErrNoRows):
			if !in.Preview {
				return nil, ErrBadPlacement
			}
			labID = ""
		case err != nil:
			return nil, fmt.Errorf("labbuild.Service.publishLab: lock lab: %w", err)
		case orgID != in.OrgID:
			return nil, ErrBuildNotFound
		default:
			// Labs published before the default existed carry 0 (free hints); 0 is never authored here.
			if _, err := tx.Exec(ctx, `UPDATE public.lab_definitions SET hint_penalty_pct = $2 WHERE id = $1 AND hint_penalty_pct = 0`,
				labID, labkinds.DefaultHintPenaltyPct); err != nil {
				return nil, fmt.Errorf("labbuild.Service.publishLab: default hint penalty: %w", err)
			}
		}
	}
	if labID == "" {
		insertID := "gen_random_uuid()"
		args := []any{in.OrgID, in.Title, kind.Name(), kind.Image(), kind.SetupScript(), defaultMaxDurationMinutes, previewPort, in.UserID, visibility, in.Build.ID, labkinds.DefaultHintPenaltyPct}
		if in.LabID != "" { // deterministic preview id
			insertID = "$12"
			args = append(args, in.LabID)
		}
		if err := tx.QueryRow(ctx, `
			INSERT INTO public.lab_definitions (id, org_id, scope, title, lab_type, environment, setup_script, max_duration,
				preview_port, created_by, library_visibility, is_published, build_id, hint_penalty_pct)
			VALUES (`+insertID+`, $1, 'standalone', $2, $3, $4, $5, $6, $7, $8, $9, false, $10, $11) RETURNING id`, args...).Scan(&labID); err != nil {
			return nil, fmt.Errorf("labbuild.Service.publishLab: create lab: %w", err)
		}
		out.Created = true
	}
	out.LabID = labID

	// 2. Live tasks from the kind's templates (deterministic ids; stale tasks parked).
	templates := kind.Tasks()
	taskIDs := make([]string, len(templates))
	for i, t := range templates {
		taskIDs[i] = canonical.ID(labID, "task:"+t.Key)
	}
	if _, err := tx.Exec(ctx, `UPDATE public.lab_tasks SET position = position + 100000 WHERE lab_id = $1 AND id <> ALL($2::uuid[])`, labID, taskIDs); err != nil {
		return nil, fmt.Errorf("labbuild.Service.publishLab: park tasks: %w", err)
	}
	snap := make([]map[string]any, 0, len(templates))
	for i, t := range templates {
		script := ""
		if t.Grader == labs.GraderScript {
			script = t.Mode
		}
		if _, err := tx.Exec(ctx, `
			INSERT INTO public.lab_tasks (id, lab_id, position, title, description, verification_script, points, is_optional, is_stateful, grader)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,false,$9)
			ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description,
				verification_script=EXCLUDED.verification_script, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, grader=EXCLUDED.grader`,
			taskIDs[i], labID, i+1, t.Title, t.Description, script, t.Points, t.IsOptional, t.Grader); err != nil {
			return nil, fmt.Errorf("labbuild.Service.publishLab: task %s: %w", t.Key, err)
		}
		snap = append(snap, map[string]any{"id": taskIDs[i], "lab_id": labID, "position": i + 1, "title": t.Title, "description": t.Description,
			"verification_script": script, "points": t.Points, "is_optional": t.IsOptional, "is_stateful": false, "grader": t.Grader})
	}

	// 3. The task version. The same build already published = nothing to cut.
	var lastID string
	var lastVersion int
	var lastBuild *string
	err = tx.QueryRow(ctx, `SELECT id, version, build_id FROM public.lab_task_versions WHERE lab_id = $1 ORDER BY version DESC LIMIT 1`, labID).
		Scan(&lastID, &lastVersion, &lastBuild)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("labbuild.Service.publishLab: latest version: %w", err)
	}
	var publishedID *string
	if err := tx.QueryRow(ctx, `SELECT published_version_id FROM public.lab_definitions WHERE id = $1`, labID).Scan(&publishedID); err != nil {
		return nil, fmt.Errorf("labbuild.Service.publishLab: published version: %w", err)
	}
	if lastBuild != nil && *lastBuild == in.Build.ID && publishedID != nil && *publishedID == lastID {
		out.VersionID, out.Version, out.Unchanged = lastID, lastVersion, true
	} else {
		raw, err := json.Marshal(snap)
		if err != nil {
			return nil, fmt.Errorf("labbuild.Service.publishLab: snapshot: %w", err)
		}
		out.Version = lastVersion + 1
		if err := tx.QueryRow(ctx, `
			INSERT INTO public.lab_task_versions (lab_id, version, tasks, published_by, build_id)
			VALUES ($1,$2,$3::jsonb,$4,$5) RETURNING id`, labID, out.Version, raw, in.UserID, in.Build.ID).Scan(&out.VersionID); err != nil {
			return nil, fmt.Errorf("labbuild.Service.publishLab: version: %w", err)
		}
		for i, t := range templates {
			script := ""
			if t.Grader == labs.GraderScript {
				script = t.Mode
			}
			if _, err := tx.Exec(ctx, `
				INSERT INTO public.lab_task_version_items (task_version_id, source_task_id, position, title, description,
					verification_script, points, is_optional, is_stateful, grader)
				VALUES ($1,$2,$3,$4,$5,$6,$7,$8,false,$9)`,
				out.VersionID, taskIDs[i], i+1, t.Title, t.Description, script, t.Points, t.IsOptional, t.Grader); err != nil {
				return nil, fmt.Errorf("labbuild.Service.publishLab: version item %s: %w", t.Key, err)
			}
		}
	}

	// 4. Publish.
	if _, err := tx.Exec(ctx, `
		UPDATE public.lab_definitions
		SET is_published = true, published_version_id = $2, build_id = $3, environment = $4, setup_script = $5,
		    preview_port = $6, updated_at = now()
		WHERE id = $1`, labID, out.VersionID, in.Build.ID, kind.Image(), kind.SetupScript(), previewPort); err != nil {
		return nil, fmt.Errorf("labbuild.Service.publishLab: publish: %w", err)
	}
	if in.Catalog != nil {
		if _, err := tx.Exec(ctx, `
			INSERT INTO public.lab_catalog_meta (lab_id, stack, category, difficulty, skills)
			VALUES ($1,$2,$3,$4,$5)
			ON CONFLICT (lab_id) DO UPDATE SET stack = EXCLUDED.stack, category = EXCLUDED.category,
				difficulty = EXCLUDED.difficulty, skills = EXCLUDED.skills`,
			labID, in.Catalog.Stack, in.Catalog.Category, in.Catalog.Difficulty, in.Catalog.Skills); err != nil {
			return nil, fmt.Errorf("labbuild.Service.publishLab: catalog: %w", err)
		}
	}
	if !in.Preview {
		if _, err := tx.Exec(ctx, `UPDATE public.lab_recipes SET lab_id = $2, updated_at = now() WHERE id = $1`, in.RecipeID, labID); err != nil {
			return nil, fmt.Errorf("labbuild.Service.publishLab: link recipe: %w", err)
		}
	}
	return out, nil
}

// catalogOf derives the catalog tags of a recipe: stack (the app's, else the
// first non-"any" block stack), category (the first non-app block's, else the
// app's), effective difficulty, and the skills of the fault blocks (what the lab
// teaches; app/data/check blocks carry shared plumbing skills that would make
// every lab look alike). A recipe without fault blocks falls back to all blocks.
func catalogOf(r *labblock.Recipe, difficulty string) *catalogMeta {
	c := &catalogMeta{Difficulty: difficulty, Stack: "any"}
	skills := map[string]bool{}
	for _, b := range r.Blocks {
		m := b.Manifest
		if c.Stack == "any" && m.Stack != "any" {
			c.Stack = m.Stack
		}
		if m.Kind == "app" {
			c.Stack = m.Stack
		}
		if c.Category == "" && m.Kind != "app" && m.Category != "" {
			c.Category = m.Category
		}
		if m.Kind == "fault" {
			for _, sk := range m.Skills {
				skills[sk] = true
			}
		}
	}
	if len(skills) == 0 {
		for _, b := range r.Blocks {
			for _, sk := range b.Manifest.Skills {
				skills[sk] = true
			}
		}
	}
	if c.Category == "" {
		for _, b := range r.Blocks {
			if b.Manifest.Category != "" {
				c.Category = b.Manifest.Category
				break
			}
		}
	}
	if c.Category == "" {
		c.Category = "general"
	}
	for sk := range skills {
		c.Skills = append(c.Skills, sk)
	}
	sort.Strings(c.Skills)
	if c.Skills == nil {
		c.Skills = []string{}
	}
	return c
}

// Publish publishes a verified build (docs/debug-labs.md B5): in ONE
// transaction it checks the build is verified for exactly the recipe's current
// hash, creates/updates the lab, cuts a task version, upserts the catalog tags,
// links the recipe and - when a placement is given (or the recipe's
// target_placement, for a new lab) - places it through library.AttachTx.
func (s *Service) Publish(ctx context.Context, orgID, userID, buildID string, req PublishReq) (*PublishResult, error) {
	b, err := s.repo.GetBuildForOrg(ctx, orgID, buildID)
	if err != nil {
		return nil, fmt.Errorf("labbuild.Publish: %w", err)
	}
	if b.Status != StatusVerified {
		return nil, ErrNotVerified
	}
	rc, err := s.authoring.Repo().GetRecipe(ctx, orgID, b.RecipeID)
	if err != nil {
		return nil, fmt.Errorf("labbuild.Publish: %w", err)
	}
	res, err := s.resolveSnapshot(ctx, Snapshot{LabKind: rc.LabKind, OrgID: orgID, Spec: rc.Spec})
	if err != nil {
		return nil, fmt.Errorf("labbuild.Publish: %w", err)
	}
	if !res.Analysis.Valid || res.Analysis.RecipeHash != b.RecipeHash {
		return nil, ErrBuildStale
	}

	if !req.placed() && rc.LabID == nil {
		req = placementFromRecipe(rc.TargetPlacement, req)
	}
	if req.placed() && s.library == nil {
		return nil, fmt.Errorf("labbuild.Service.Publish: placement is not available in this process")
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("labbuild.Service.Publish: begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	labID := ""
	if rc.LabID != nil {
		labID = *rc.LabID
	}
	pub, err := s.publishLab(ctx, tx, publishIn{
		OrgID: orgID, UserID: userID, Build: b, Kind: res.Kind, LabID: labID, Title: rc.Title,
		RecipeID: rc.ID, Catalog: catalogOf(res.Recipe, res.Analysis.Difficulty),
	})
	if err != nil {
		return nil, err
	}
	result := &PublishResult{LabID: pub.LabID, TaskVersionID: pub.VersionID, Version: pub.Version, Republished: !pub.Created, Unchanged: pub.Unchanged}

	if req.placed() {
		mod, err := s.library.AttachTx(ctx, tx, orgID, userID, library.AttachReq{
			SectionID: req.SectionID, Position: req.Position, Kind: library.KindLab, ItemID: pub.LabID, IsRequired: req.IsRequired,
		})
		if err != nil {
			return nil, err
		}
		if req.CourseID != "" && mod.CourseID != req.CourseID {
			return nil, fmt.Errorf("%w: section %s is not in course %s", ErrBadPlacement, req.SectionID, req.CourseID)
		}
		result.Module = &mod
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("labbuild.Service.Publish: commit: %w", err)
	}
	return result, nil
}

// placementFromRecipe fills a placement from lab_recipes.target_placement
// ({course_id, section_id, position}) when the request gave none.
func placementFromRecipe(raw json.RawMessage, req PublishReq) PublishReq {
	var tp struct {
		CourseID  string `json:"course_id"`
		SectionID string `json:"section_id"`
		Position  *int   `json:"position"`
	}
	if len(raw) == 0 || json.Unmarshal(raw, &tp) != nil || tp.SectionID == "" {
		return req
	}
	req.CourseID, req.SectionID, req.Position = tp.CourseID, tp.SectionID, tp.Position
	return req
}

// autoPublish publishes a verified platform-recipe build into its existing lab
// (the generated, unpublished lab_definitions row); it never places a lab.
func (s *Service) autoPublish(ctx context.Context, b *Build) error {
	rc, err := s.authoring.Repo().GetRecipe(ctx, b.Snapshot.OrgID, b.RecipeID)
	if err != nil {
		return fmt.Errorf("labbuild.autoPublish: %w", err)
	}
	res, err := s.resolveSnapshot(ctx, Snapshot{LabKind: rc.LabKind, OrgID: rc.OrgID, Spec: rc.Spec})
	if err != nil {
		return fmt.Errorf("labbuild.autoPublish: %w", err)
	}
	if !res.Analysis.Valid || res.Analysis.RecipeHash != b.RecipeHash {
		return ErrBuildStale
	}
	labID := ""
	if rc.LabID != nil {
		labID = *rc.LabID
	}
	if labID == "" {
		return fmt.Errorf("labbuild.Service.autoPublish: platform recipe %s has no lab", rc.ID)
	}
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("labbuild.Service.autoPublish: begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if _, err := s.publishLab(ctx, tx, publishIn{
		OrgID: rc.OrgID, UserID: rc.OwnerID, Build: b, Kind: res.Kind, LabID: labID, Title: rc.Title,
		RecipeID: rc.ID, Catalog: catalogOf(res.Recipe, res.Analysis.Difficulty),
	}); err != nil {
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("labbuild.Service.autoPublish: commit: %w", err)
	}
	slog.Info("labbuild: platform lab published", "recipe_id", rc.ID, "lab_id", labID, "build_id", b.ID)
	return nil
}

// Preview starts an instructor is_test session on a chosen variant of a
// verified build, through the normal labs start path (docs/debug-labs.md B4
// step 11). A hidden per-recipe preview lab carries the build; it is private
// to the org's library and never listed in the catalog.
func (s *Service) Preview(ctx context.Context, orgID, userID, buildID, variantKey string) (*labs.LabSession, error) {
	b, err := s.repo.GetBuildForOrg(ctx, orgID, buildID)
	if err != nil {
		return nil, fmt.Errorf("labbuild.Preview: %w", err)
	}
	if b.Status != StatusVerified {
		return nil, ErrNotVerified
	}
	variants, err := s.repo.ListVariants(ctx, b.ID)
	if err != nil {
		return nil, fmt.Errorf("labbuild.Preview: %w", err)
	}
	if variantKey == "" && len(variants) > 0 {
		variantKey = variants[0].Key
	}
	found := false
	for _, v := range variants {
		found = found || v.Key == variantKey
	}
	if !found {
		return nil, ErrVariantUnknown
	}
	kind, ok := labkinds.Get(b.Snapshot.LabKind)
	if !ok {
		return nil, labauthor.ErrUnknownLabKind
	}
	rc, err := s.authoring.Repo().GetRecipe(ctx, orgID, b.RecipeID)
	if err != nil {
		return nil, fmt.Errorf("labbuild.Preview: %w", err)
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("labbuild.Service.Preview: begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	pub, err := s.publishLab(ctx, tx, publishIn{
		OrgID: orgID, UserID: userID, Build: b, Kind: kind, LabID: canonical.ID(rc.ID, previewLabSuffix),
		Title: previewTitlePrefix + rc.Title, Preview: true, RecipeID: rc.ID,
	})
	if err != nil {
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("labbuild.Service.Preview: commit: %w", err)
	}
	return s.labs.StartSession(labs.WithVariantOverride(ctx, variantKey), pub.LabID, userID, orgID, true, "", nil)
}
