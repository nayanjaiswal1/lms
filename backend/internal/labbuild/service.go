package labbuild

import (
	"context"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/labauthor"
	"github.com/mindforge/backend/internal/labblock"
	"github.com/mindforge/backend/internal/labkinds"
	"github.com/mindforge/backend/internal/labs"
	"github.com/mindforge/backend/internal/library"
	"github.com/mindforge/backend/internal/ratelimit"
	"github.com/mindforge/backend/internal/storage"
	"github.com/redis/go-redis/v9"
)

// Timeouts and limits of the pipeline. They describe the pipeline's own
// mechanics (sandbox exec budgets, job budgets), not tenant policy.
const (
	renderExecTimeoutSeconds = 600
	renderJobTimeoutMS       = 15 * 60 * 1000
	verifyJobTimeoutMS       = 40 * 60 * 1000
	jobMaxRetries            = 2
	// stuckBuildGrace: an in-flight build older than this with no live
	// render/verify job is failed (as infra) by lab.build_gc; the grace
	// covers the instant between CreateBuild and its job being enqueued.
	stuckBuildGrace    = 10 * time.Minute
	buildRateWindow    = 24 * time.Hour
	outputDir          = "/tmp/mf-out"
	rendererCmd        = "python3 -I /opt/mindforge/mf-build --out " + outputDir
	permCoursesPublish = "courses.publish"
)

// Config carries the operator-tunable limits.
type Config struct {
	// BuildsPerUserDay caps builds an instructor may start per rolling day.
	BuildsPerUserDay int
	// VerifyParallelPerOrg bounds concurrent verification sandboxes per org.
	VerifyParallelPerOrg int
	// ValidatePodsMax bounds validation sandboxes (render, verify runs and
	// runtime probes together) across every worker and org.
	ValidatePodsMax int
	// BuildDeadline: a build still waiting for validation capacity this long
	// after it was queued fails as an infra failure.
	BuildDeadline time.Duration
}

// NewConfig maps the operator settings (config.Config) to the pipeline's limits.
func NewConfig(cfg *config.Config) Config {
	return Config{
		BuildsPerUserDay: cfg.LabBuildsPerUserDay, VerifyParallelPerOrg: cfg.LabVerifyParallelPerOrg,
		ValidatePodsMax: cfg.LabBuildValidatePodsMax,
		BuildDeadline:   cfg.LabBuildDeadline,
	}
}

// RegisterJobs registers the pipeline's job handlers, dead hooks and their
// scheduling limits on reg. Render and verify jobs each hold a worker slot
// while a sandbox runs, so they are capped at ValidatePodsMax running jobs per
// handler (more could only wait for a pod slot) and can never starve the
// pool. All three handlers are idempotent (status guards, content-addressed
// uploads), so a shutdown requeues them without consuming a retry.
func (s *Service) RegisterJobs(reg *jobs.Registry) {
	reg.Register(HandlerRecipeBuild, s.BuildJob())
	reg.Register(HandlerRecipeVerify, s.VerifyJob())
	reg.Register(HandlerBuildGC, s.BuildGCJob())
	reg.OnDead(HandlerRecipeBuild, s.DeadHook())
	reg.OnDead(HandlerRecipeVerify, s.DeadHook())
	for _, h := range []string{HandlerRecipeBuild, HandlerRecipeVerify} {
		reg.SetMaxConcurrent(h, max(s.cfg.ValidatePodsMax, 1))
	}
	for _, h := range []string{HandlerRecipeBuild, HandlerRecipeVerify, HandlerBuildGC} {
		reg.SetResumable(h)
	}
}

// Service is the build pipeline: API operations plus the job bodies.
type Service struct {
	pool      *pgxpool.Pool
	rdb       *redis.Client
	runtime   labs.ContainerRuntime
	store     storage.PrivateStore
	labs      *labs.Service
	library   *library.Service
	authoring *labauthor.Service
	jobs      *jobs.Registry
	limiter   *ratelimit.Limiter
	cfg       Config
	repo      *Repo
	labsRepo  *labs.Repo
	sem       *ratelimit.Semaphore
}

// New wires the pipeline. labsSvc supplies clean-room grading (and, on the API
// side, preview session starts); lib may be nil in the worker process (publish
// through the API only; the labset import never places a lab).
func New(pool *pgxpool.Pool, rdb *redis.Client, runtime labs.ContainerRuntime, store storage.PrivateStore,
	labsSvc *labs.Service, lib *library.Service, authoring *labauthor.Service, reg *jobs.Registry, cfg Config) *Service {
	return &Service{
		pool: pool, rdb: rdb, runtime: runtime, store: store, labs: labsSvc, library: lib, authoring: authoring,
		jobs: reg, limiter: ratelimit.New(rdb), cfg: cfg, repo: NewRepo(pool), labsRepo: labs.NewRepo(pool),
		sem: ratelimit.NewSemaphore(rdb),
	}
}

// resolved is a recipe re-resolved and re-validated from a build's frozen spec.
type resolved struct {
	Recipe   *labblock.Recipe
	Analysis *labauthor.Analysis
	Kind     labkinds.Kind
}

// resolveSnapshot rebuilds the recipe from the frozen spec (never the live
// recipe row) and re-runs the composition validator, including org scoping.
func (s *Service) resolveSnapshot(ctx context.Context, snap Snapshot) (*resolved, error) {
	kind, ok := labkinds.Get(snap.LabKind)
	if !ok {
		return nil, fmt.Errorf("%w: %q", labauthor.ErrUnknownLabKind, snap.LabKind)
	}
	ids := make([]string, 0, len(snap.Spec.Blocks))
	for _, b := range snap.Spec.Blocks {
		ids = append(ids, b.BlockVersionID)
	}
	vers, err := s.authoring.Repo().ResolveVersions(ctx, snap.OrgID, ids)
	if err != nil {
		return nil, fmt.Errorf("labbuild.resolveSnapshot: %w", err)
	}
	recipe, missing := labauthor.BuildRecipe(snap.LabKind, snap.OrgID, snap.Spec, vers)
	if len(missing) > 0 {
		return &resolved{Recipe: recipe, Analysis: &labauthor.Analysis{Issues: missing}, Kind: kind}, nil
	}
	return &resolved{Recipe: recipe, Analysis: labauthor.Analyze(recipe), Kind: kind}, nil
}

// variantSeed derives a stable positive int64 seed for a variant.
func variantSeed(recipeHash, variantKey string, specSeed int64) int64 {
	sum := sha256.Sum256([]byte(fmt.Sprintf("%s|%s|%d", recipeHash, variantKey, specSeed)))
	return int64(binary.BigEndian.Uint64(sum[:8]) &^ (1 << 63))
}

// runSeed derives a hex grader seed (grade.sh accepts 8-64 hex chars).
func runSeed(buildID, variantKey, run string, i int) string {
	sum := sha256.Sum256([]byte(fmt.Sprintf("%s|%s|%s|%d", buildID, variantKey, run, i)))
	return hex.EncodeToString(sum[:12])
}

func ptr[T any](v T) *T { return &v }

// enqueue puts a pipeline job on the queue, one job row per (handler, build):
// a busy pipeline defers that same row (jobs.RetryAfter) instead of enqueueing
// another, so a duplicate idempotency key means it is already queued, which is
// fine.
func (s *Service) enqueue(ctx context.Context, handler, buildID, createdBy string, timeoutMS int) (string, error) {
	job, err := jobs.Enqueue(ctx, s.pool, s.jobs, jobs.EnqueueParams{
		Handler: handler, Priority: jobs.PriorityNormal, Payload: map[string]string{"build_id": buildID},
		MaxRetries: ptr(jobMaxRetries), TimeoutMS: ptr(timeoutMS),
		IdempotencyKey: ptr(handler + ":" + buildID), CreatedBy: ptr(createdBy),
	})
	if err != nil && !errors.Is(err, jobs.ErrDuplicateKey) {
		return "", fmt.Errorf("labbuild.Service.enqueue %s: %w", handler, err)
	}
	return job.ID, nil
}
