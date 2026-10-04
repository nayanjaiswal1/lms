package labbuild

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"

	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/labauthor"
)

// gcRetentionDays is how long a failed or superseded, unpublished build (and
// its variants) is kept before lab.build_gc deletes it. Its bundles are then
// unreferenced and reclaimed by lab.bundle_gc.
const gcRetentionDays = 30

type buildPayload struct {
	BuildID string `json:"build_id"`
}

// jobFunc adapts a function to jobs.Handler.
type jobFunc func(ctx context.Context, job jobs.Job) error

func (f jobFunc) Handle(ctx context.Context, job jobs.Job) error { return f(ctx, job) }

func buildIDOf(job jobs.Job) (string, error) {
	var p buildPayload
	if err := json.Unmarshal(job.Payload, &p); err != nil || p.BuildID == "" {
		return "", fmt.Errorf("labbuild: job %s has no build_id", job.ID)
	}
	return p.BuildID, nil
}

// BuildJob is the lab.recipe_build handler.
func (s *Service) BuildJob() jobs.Handler {
	return jobFunc(func(ctx context.Context, job jobs.Job) error {
		id, err := buildIDOf(job)
		if err != nil {
			return err
		}
		return s.RunBuild(ctx, id)
	})
}

// VerifyJob is the lab.recipe_verify handler.
func (s *Service) VerifyJob() jobs.Handler {
	return jobFunc(func(ctx context.Context, job jobs.Job) error {
		id, err := buildIDOf(job)
		if err != nil {
			return err
		}
		return s.RunVerify(ctx, id)
	})
}

// PlatformRecipesJob is the lab.platform_recipes_sync handler.
func (s *Service) PlatformRecipesJob() jobs.Handler {
	return jobFunc(func(ctx context.Context, _ jobs.Job) error { return s.SyncPlatformRecipes(ctx) })
}

// BuildGCJob is the lab.build_gc handler.
func (s *Service) BuildGCJob() jobs.Handler {
	return jobFunc(func(ctx context.Context, _ jobs.Job) error { return s.GCBuilds(ctx) })
}

// DeadHook fails a build whose pipeline job died after exhausting its retries,
// so it never sits in rendering/verifying forever.
func (s *Service) DeadHook() jobs.DeadLetterHook {
	return func(ctx context.Context, job jobs.Job) {
		id, err := buildIDOf(job)
		if err != nil {
			return
		}
		msg := "the build job failed permanently"
		if job.LastError != nil {
			msg += ": " + *job.LastError
		}
		if _, err := s.repo.Finish(ctx, id, StatusFailed, Report{Error: msg}); err != nil {
			slog.Error("labbuild: dead hook", "build_id", id, "error", err)
		}
	}
}

// SyncPlatformRecipes builds and auto-publishes platform recipes (recipes
// emitted by `coursegen generate` from a lab's recipe.yaml, docs/debug-labs.md
// B5 "Platform course content"). For each one: no build of its current hash ->
// queue one with auto-publish; a verified build the lab is not on -> publish
// it. Failed and in-flight builds are left alone (change the recipe or its
// blocks to retry), so a broken recipe cannot rebuild in a loop.
func (s *Service) SyncPlatformRecipes(ctx context.Context) error {
	rows, err := s.pool.Query(ctx, `
		SELECT r.id, r.org_id, COALESCE(ld.build_id::text, '')
		FROM public.lab_recipes r LEFT JOIN public.lab_definitions ld ON ld.id = r.lab_id
		WHERE r.is_platform AND r.lab_id IS NOT NULL ORDER BY r.created_at`)
	if err != nil {
		return fmt.Errorf("labbuild.Service.SyncPlatformRecipes: %w", err)
	}
	type row struct{ id, org, labBuild string }
	var todo []row
	for rows.Next() {
		var r row
		if err := rows.Scan(&r.id, &r.org, &r.labBuild); err != nil {
			rows.Close()
			return fmt.Errorf("labbuild.Service.SyncPlatformRecipes: scan: %w", err)
		}
		todo = append(todo, r)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return fmt.Errorf("labbuild.Service.SyncPlatformRecipes: rows: %w", err)
	}

	for _, r := range todo {
		if err := s.syncOne(ctx, r.id, r.org, r.labBuild); err != nil {
			slog.Error("labbuild: platform recipe sync", "recipe_id", r.id, "error", err)
		}
	}
	return nil
}

func (s *Service) syncOne(ctx context.Context, recipeID, orgID, labBuildID string) error {
	rc, err := s.authoring.Repo().GetRecipe(ctx, orgID, recipeID)
	if err != nil {
		return err
	}
	snap := Snapshot{LabKind: rc.LabKind, OrgID: orgID, Spec: rc.Spec, AutoPublish: true}
	res, err := s.resolveSnapshot(ctx, snap)
	if err != nil {
		return err
	}
	if !res.Analysis.Valid {
		return &labauthor.InvalidRecipeError{Analysis: res.Analysis}
	}
	latest, err := s.repo.LatestBuild(ctx, rc.ID, res.Analysis.RecipeHash)
	if err != nil {
		return err
	}
	switch {
	case latest == nil:
		_, err := s.startBuild(ctx, rc.ID, rc.OwnerID, snap, res.Analysis, false)
		return err
	case latest.Status == StatusVerified && latest.ID != labBuildID:
		return s.autoPublish(ctx, latest)
	}
	return nil
}

// GCBuilds deletes unpublished builds older than gcRetentionDays that are
// failed, or verified but superseded by a newer build of the same recipe. A
// build a lab or a task version points at is never touched.
func (s *Service) GCBuilds(ctx context.Context) error {
	tag, err := s.pool.Exec(ctx, `
		DELETE FROM public.lab_builds b
		WHERE b.created_at < now() - make_interval(days => $1)
		  AND b.status IN ('failed', 'verified')
		  AND NOT EXISTS (SELECT 1 FROM public.lab_definitions ld WHERE ld.build_id = b.id)
		  AND NOT EXISTS (SELECT 1 FROM public.lab_task_versions tv WHERE tv.build_id = b.id)
		  AND (b.status = 'failed' OR EXISTS (
		        SELECT 1 FROM public.lab_builds n WHERE n.recipe_id = b.recipe_id AND n.created_at > b.created_at))`, gcRetentionDays)
	if err != nil {
		return fmt.Errorf("labbuild.Service.GCBuilds: %w", err)
	}
	if n := tag.RowsAffected(); n > 0 {
		slog.Info("lab.build_gc: removed builds", "count", n)
	}
	return nil
}
