package labbuild

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"

	"github.com/mindforge/backend/internal/jobs"
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

// BuildGCJob is the lab.build_gc handler.
func (s *Service) BuildGCJob() jobs.Handler {
	return jobFunc(func(ctx context.Context, _ jobs.Job) error { return s.GCBuilds(ctx) })
}

// DeadHook fails a build whose pipeline job died after exhausting its retries,
// so it never sits in rendering/verifying forever. A dead job is a platform
// failure (the recipe's own faults fail the build without failing the job),
// so the build is marked infra: the author sees it was not their recipe and
// can simply build again.
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
		if _, err := s.repo.Finish(ctx, id, StatusFailed, Report{Error: msg, Infra: true}); err != nil {
			slog.Error("labbuild: dead hook", "build_id", id, "error", err)
		}
	}
}

// GCBuilds first fails stuck in-flight builds (in flight longer than
// stuckBuildGrace with no live render/verify job, Repo.FailStuck), then deletes
// unpublished builds older than gcRetentionDays that are failed, or verified
// but superseded by a newer build of the same recipe. A build a lab or a task
// version points at is never touched.
func (s *Service) GCBuilds(ctx context.Context) error {
	if n, err := s.repo.FailStuck(ctx, stuckBuildGrace); err != nil {
		return fmt.Errorf("labbuild.Service.GCBuilds: %w", err)
	} else if n > 0 {
		slog.Warn("lab.build_gc: failed stuck builds with no live job", "count", n)
	}
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
