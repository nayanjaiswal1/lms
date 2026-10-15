package labbuild

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"sync/atomic"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/labkinds"
	"github.com/mindforge/backend/internal/labs"
	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testredis"
)

// fakeRuntime counts validation sandbox starts. Any other runtime call panics
// (nil embedded interface): these tests must never reach a real sandbox.
type fakeRuntime struct {
	labs.ContainerRuntime
	starts atomic.Int32
}

func (f *fakeRuntime) StartValidation(context.Context, string, string) (string, string, error) {
	f.starts.Add(1)
	return "", "", errors.New("fakeRuntime: no sandboxes in tests")
}

func newTestService(t *testing.T, pool *pgxpool.Pool, cfg Config) (*Service, *fakeRuntime) {
	t.Helper()
	rt := &fakeRuntime{}
	return New(pool, testredis.New(t), rt, nil, nil, nil, nil, nil, cfg), rt
}

// fillPodSlots holds every global validation-pod slot until the test ends.
func fillPodSlots(t *testing.T, s *Service) {
	t.Helper()
	for i := 0; i < max(s.cfg.ValidatePodsMax, 1); i++ {
		l, err := s.acquirePod(context.Background(), "")
		if err != nil || l == nil {
			t.Fatalf("fill slot %d: %v %v", i, l, err)
		}
		t.Cleanup(l.Release)
	}
}

// seedBuild inserts an org, user, recipe and a build in status created age ago.
func seedBuild(t *testing.T, pool *pgxpool.Pool, status string, age time.Duration) string {
	t.Helper()
	ctx := context.Background()
	sfx := fmt.Sprintf("%d", time.Now().UnixNano())
	var org, user, recipe, build string
	must := func(err error) {
		t.Helper()
		if err != nil {
			t.Fatalf("seed: %v", err)
		}
	}
	must(pool.QueryRow(ctx, `INSERT INTO organizations (name, slug) VALUES ($1, $2) RETURNING id`, "Org "+sfx, "o"+sfx).Scan(&org))
	must(pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ($1, 'U') RETURNING id`, "u"+sfx+"@example.com").Scan(&user))
	must(pool.QueryRow(ctx, `INSERT INTO lab_recipes (org_id, owner_id, lab_kind, title, spec)
		VALUES ($1, $2, 'debug', 'R', '{}') RETURNING id`, org, user).Scan(&recipe))
	snap := fmt.Sprintf(`{"lab_kind":"debug","org_id":%q,"spec":{"blocks":[]}}`, org)
	must(pool.QueryRow(ctx, `INSERT INTO lab_builds (recipe_id, recipe_hash, runtime_id, spec_snapshot, status, created_by, created_at)
		VALUES ($1, 'hash-'||$5::text, 'rt', $2::jsonb, $3, $4, now() - make_interval(secs => $6)) RETURNING id`,
		recipe, snap, status, user, sfx, age.Seconds()).Scan(&build))
	return build
}

func buildState(t *testing.T, pool *pgxpool.Pool, id string) (string, Report) {
	t.Helper()
	var status string
	var raw []byte
	if err := pool.QueryRow(context.Background(), `SELECT status, COALESCE(report, '{}') FROM lab_builds WHERE id = $1`, id).Scan(&status, &raw); err != nil {
		t.Fatalf("read build: %v", err)
	}
	var rep Report
	if err := json.Unmarshal(raw, &rep); err != nil {
		t.Fatalf("report: %v", err)
	}
	return status, rep
}

// Regression: every render started a validation Pod regardless of capacity,
// holding a worker slot while it sat Pending. With no free pod slot the render
// job must defer (RetryAfter: frees the slot, consumes no retry), start no
// sandbox, and leave the build queued.
func TestRunBuildDefersWhenNoPodSlot(t *testing.T) {
	pool := testdb.New(t)
	s, rt := newTestService(t, pool, Config{ValidatePodsMax: 1, BuildDeadline: time.Hour})
	fillPodSlots(t, s)
	id := seedBuild(t, pool, StatusQueued, 0)

	err := s.RunBuild(context.Background(), id)
	var ra *jobs.RetryAfterError
	if !errors.As(err, &ra) {
		t.Fatalf("err = %v, want jobs.RetryAfter", err)
	}
	if n := rt.starts.Load(); n != 0 {
		t.Fatalf("started %d sandboxes with no free slot", n)
	}
	if status, _ := buildState(t, pool, id); status != StatusQueued {
		t.Fatalf("status = %s, want queued", status)
	}
}

// A build that waited longer than the deadline fails as an infra failure
// instead of deferring forever.
func TestDeferBuildPastDeadlineFailsAsInfra(t *testing.T) {
	pool := testdb.New(t)
	s, _ := newTestService(t, pool, Config{ValidatePodsMax: 1, BuildDeadline: time.Hour})
	id := seedBuild(t, pool, StatusVerifying, 2*time.Hour)
	b, err := s.repo.GetBuild(context.Background(), id)
	if err != nil {
		t.Fatal(err)
	}
	if err := s.deferBuild(context.Background(), b, Report{VariantCount: 3}, errNoCapacity); err != nil {
		t.Fatalf("deferBuild: %v", err)
	}
	status, rep := buildState(t, pool, id)
	if status != StatusFailed || !rep.Infra || rep.VariantCount != 3 {
		t.Fatalf("status=%s report=%+v, want failed + infra with partial report kept", status, rep)
	}
}

// Regression: builds whose job vanished (died before the dead hook ran, was
// cancelled, or was never enqueued) stayed in flight forever, blocking every
// new build of their hash. Only those are failed - never one with a live job
// or one younger than the grace.
func TestFailStuckOnlyFailsBuildsWithoutLiveJob(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	s, _ := newTestService(t, pool, Config{ValidatePodsMax: 1})
	stuck := seedBuild(t, pool, StatusRendering, time.Hour)
	live := seedBuild(t, pool, StatusVerifying, time.Hour)
	fresh := seedBuild(t, pool, StatusQueued, 0)
	if _, err := pool.Exec(ctx, `INSERT INTO jobs (handler, status, payload) VALUES ($1, 'pending', jsonb_build_object('build_id', $2::text))`,
		HandlerRecipeVerify, live); err != nil {
		t.Fatal(err)
	}
	// A finished job for the stuck build must not count as live.
	if _, err := pool.Exec(ctx, `INSERT INTO jobs (handler, status, payload) VALUES ($1, 'dead', jsonb_build_object('build_id', $2::text))`,
		HandlerRecipeBuild, stuck); err != nil {
		t.Fatal(err)
	}

	// lab.build_gc is FailStuck's periodic caller.
	if err := s.GCBuilds(ctx); err != nil {
		t.Fatal(err)
	}
	if status, rep := buildState(t, pool, stuck); status != StatusFailed || !rep.Infra {
		t.Fatalf("stuck build: %s %+v, want failed + infra", status, rep)
	}
	for _, id := range []string{live, fresh} {
		if status, _ := buildState(t, pool, id); status == StatusFailed {
			t.Fatalf("build %s with a live job / inside grace was failed", id)
		}
	}
}

// Regression: a dead pipeline job marked the build plainly failed, as if the
// recipe were broken. It is an infra failure.
func TestDeadHookMarksInfra(t *testing.T) {
	pool := testdb.New(t)
	s, _ := newTestService(t, pool, Config{})
	id := seedBuild(t, pool, StatusRendering, 0)
	msg := "orphan: worker heartbeat lost"
	s.DeadHook()(context.Background(), jobs.Job{Payload: json.RawMessage(fmt.Sprintf(`{"build_id":%q}`, id)), LastError: &msg})
	if status, rep := buildState(t, pool, id); status != StatusFailed || !rep.Infra {
		t.Fatalf("status=%s report=%+v, want failed + infra", status, rep)
	}
}

// Regression: with no free CPU the runtime probe started a Pod that sat
// Pending until the 120s sync job timed out. With no pod slot it must not
// start a sandbox, and must fall back to the last known stamp.
func TestRuntimeIDUsesLastKnownStampWithoutCapacity(t *testing.T) {
	s, rt := newTestService(t, nil, Config{ValidatePodsMax: 1})
	fillPodSlots(t, s)
	ctx := context.Background()
	kind, _ := labkinds.Get("debug")

	if _, err := s.runtimeID(ctx, "debug"); !errors.Is(err, errNoCapacity) {
		t.Fatalf("no stamp known: err = %v, want errNoCapacity", err)
	}
	if err := s.rdb.Set(ctx, runtimeLastKeyPrefix+kind.Image(), "stamp-1", time.Hour).Err(); err != nil {
		t.Fatal(err)
	}
	id, err := s.runtimeID(ctx, "debug")
	if err != nil || id != "stamp-1" {
		t.Fatalf("runtimeID = %q, %v; want the last known stamp", id, err)
	}
	if n := rt.starts.Load(); n != 0 {
		t.Fatalf("started %d probe sandboxes with no free slot", n)
	}
}

// A run whose sandbox the cluster could not schedule is deferred like a full
// semaphore, not counted as a failed verification (which burns retries).
func TestExecuteRunDefersUnschedulable(t *testing.T) {
	kind, _ := labkinds.Get("debug")
	grade := func(context.Context, labs.GradeTarget, *labkinds.VariantView, []byte, []string, string) (map[string]*labs.GradeResult, error) {
		return nil, fmt.Errorf("labs.GradeModesInSandbox: start: %w", labs.ErrUnschedulable)
	}
	bundles := &variantBundles{view: &labkinds.VariantView{VariantKey: "v"}}
	_, err := executeRun(context.Background(), nil, grade, "b", "o", kind, bundles, labkinds.VerifyRun{Name: "broken", Seeds: 1}, nil)
	if !errors.Is(err, errRunBusy) {
		t.Fatalf("err = %v, want errRunBusy", err)
	}
}
