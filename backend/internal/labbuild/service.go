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
	buildRateWindow          = 24 * time.Hour
	outputDir                = "/tmp/mf-out"
	rendererCmd              = "python3 -I /opt/mindforge/mf-build --out " + outputDir
	permCoursesPublish       = "courses.publish"
)

// Config carries the operator-tunable limits.
type Config struct {
	// BuildsPerUserDay caps builds an instructor may start per rolling day.
	BuildsPerUserDay int
	// VerifyParallelPerOrg bounds concurrent verification sandboxes per org.
	VerifyParallelPerOrg int
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
// through the API only; auto-publish of platform recipes never places a lab).
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
		return nil, err
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

// enqueue puts a pipeline job on the queue. A duplicate idempotency key means
// it is already queued, which is fine.
func (s *Service) enqueue(ctx context.Context, handler, buildID, createdBy string, timeoutMS int) (string, error) {
	return s.enqueueAt(ctx, handler, buildID, createdBy, timeoutMS, nil, "")
}

// enqueueAt is enqueue with an optional run time (a delayed re-enqueue) and an
// idempotency-key suffix, so a deferred job does not collide with its predecessor.
func (s *Service) enqueueAt(ctx context.Context, handler, buildID, createdBy string, timeoutMS int, runAt *time.Time, keySuffix string) (string, error) {
	job, err := jobs.Enqueue(ctx, s.pool, s.jobs, jobs.EnqueueParams{
		Handler: handler, Priority: jobs.PriorityNormal, Payload: map[string]string{"build_id": buildID},
		MaxRetries: ptr(jobMaxRetries), TimeoutMS: ptr(timeoutMS), RunAt: runAt,
		IdempotencyKey: ptr(handler + ":" + buildID + keySuffix), CreatedBy: ptr(createdBy),
	})
	if err != nil && !errors.Is(err, jobs.ErrDuplicateKey) {
		return "", fmt.Errorf("labbuild.Service.enqueue %s: %w", handler, err)
	}
	return job.ID, nil
}
