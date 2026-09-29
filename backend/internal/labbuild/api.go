package labbuild

import (
	"context"
	"errors"
	"log/slog"

	"github.com/mindforge/backend/internal/labauthor"
)

const buildRateKeyPrefix = "rl:labbuild:user:"

// StartResult is the outcome of requesting a build.
type StartResult struct {
	Build *Build
	// Reused is true when the recipe already has a verified build for the same
	// hash (nothing new is queued). Queued is true for a freshly queued build;
	// neither means an in-flight build was found.
	Reused bool
	Queued bool
}

// StartBuild validates a recipe and queues a build of it (docs/debug-labs.md B3).
// A verified build for the same recipe hash is reused; an in-flight one is
// returned as-is; otherwise a new build is queued, subject to the per-instructor
// daily limit.
func (s *Service) StartBuild(ctx context.Context, orgID, userID, recipeID string) (*StartResult, error) {
	rc, err := s.authoring.Repo().GetRecipe(ctx, orgID, recipeID)
	if err != nil {
		return nil, err
	}
	snap := Snapshot{LabKind: rc.LabKind, OrgID: orgID, Spec: rc.Spec}
	res, err := s.resolveSnapshot(ctx, snap)
	if err != nil {
		return nil, err
	}
	if !res.Analysis.Valid || res.Analysis.RecipeHash == "" {
		return nil, &labauthor.InvalidRecipeError{Analysis: res.Analysis}
	}
	return s.startBuild(ctx, rc.ID, userID, snap, res.Analysis, true)
}

// startBuild is the shared queue path (API and platform sync). limited applies
// the per-user daily limit.
func (s *Service) startBuild(ctx context.Context, recipeID, userID string, snap Snapshot, a *labauthor.Analysis, limited bool) (*StartResult, error) {
	if prev, err := s.repo.LatestBuild(ctx, recipeID, a.RecipeHash); err != nil {
		return nil, err
	} else if prev != nil {
		switch prev.Status {
		case StatusVerified:
			return &StartResult{Build: prev, Reused: true}, nil
		case StatusQueued, StatusRendering, StatusVerifying:
			return &StartResult{Build: prev}, nil
		}
	}
	if limited {
		key := buildRateKeyPrefix + userID
		if allowed, _ := s.limiter.Allow(ctx, key, s.cfg.BuildsPerUserDay, buildRateWindow); !allowed {
			return nil, ErrBuildRateLimit
		}
	}
	b, err := s.repo.CreateBuild(ctx, recipeID, a.RecipeHash, snap, a.Difficulty, userID)
	if errors.Is(err, ErrBuildInFlight) {
		return &StartResult{Build: b}, nil
	}
	if err != nil {
		return nil, err
	}
	jobID, err := s.enqueue(ctx, HandlerRecipeBuild, b.ID, userID, renderJobTimeoutMS)
	if err != nil {
		_, _ = s.repo.Finish(context.Background(), b.ID, StatusFailed, Report{Error: "could not queue the build job"})
		slog.Error("labbuild: enqueue build", "build_id", b.ID, "error", err)
		return nil, ErrNoWorker
	}
	if err := s.repo.SetJob(ctx, b.ID, jobID); err != nil {
		slog.Warn("labbuild: record job id", "build_id", b.ID, "error", err)
	}
	return &StartResult{Build: b, Queued: true}, nil
}

// GetBuild returns an org's build (status + report).
func (s *Service) GetBuild(ctx context.Context, orgID, buildID string) (*Build, error) {
	return s.repo.GetBuildForOrg(ctx, orgID, buildID)
}

// BuildView is the GET /builds/{id} payload: the build plus its variants' keys.
type BuildView struct {
	*Build
	Variants []string `json:"variants"`
}

// View loads a build with its variant keys.
func (s *Service) View(ctx context.Context, orgID, buildID string) (*BuildView, error) {
	b, err := s.repo.GetBuildForOrg(ctx, orgID, buildID)
	if err != nil {
		return nil, err
	}
	vs, err := s.repo.ListVariants(ctx, b.ID)
	if err != nil {
		return nil, err
	}
	keys := make([]string, 0, len(vs))
	for _, v := range vs {
		keys = append(keys, v.Key)
	}
	return &BuildView{Build: b, Variants: keys}, nil
}
