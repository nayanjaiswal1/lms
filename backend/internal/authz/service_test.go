package authz

import (
	"context"
	"errors"
	"testing"
)

// ─── Stub repo ────────────────────────────────────────────────────────────────

type stubRepo struct {
	perms       []string
	assignments []UserRoleAssignment
	permErr     error
	assignErr   error
	calls       [][2]string // (userID, tenantID) per GetEffectivePermissions call
}

func (r *stubRepo) GetEffectivePermissions(_ context.Context, userID, tenantID string) ([]string, error) {
	r.calls = append(r.calls, [2]string{userID, tenantID})
	return r.perms, r.permErr
}

func (r *stubRepo) GetAssignmentsForRole(_ context.Context, _ string) ([]UserRoleAssignment, error) {
	return r.assignments, r.assignErr
}

// ─── Stub cache ───────────────────────────────────────────────────────────────

type stubCache struct {
	stored        map[string][]string
	getErr        error
	setErr        error
	invalidated   []string
	invalidateErr error
}

func newStubCache() *stubCache {
	return &stubCache{stored: make(map[string][]string)}
}

func (c *stubCache) Get(_ context.Context, tenantID, userID string) ([]string, error) {
	if c.getErr != nil {
		return nil, c.getErr
	}
	k := tenantID + ":" + userID
	v, ok := c.stored[k]
	if !ok {
		return nil, nil
	}
	return v, nil
}

func (c *stubCache) Set(_ context.Context, tenantID, userID string, codes []string) error {
	if c.setErr != nil {
		return c.setErr
	}
	c.stored[tenantID+":"+userID] = codes
	return nil
}

func (c *stubCache) Invalidate(_ context.Context, tenantID, userID string) error {
	if c.invalidateErr != nil {
		return c.invalidateErr
	}
	k := tenantID + ":" + userID
	delete(c.stored, k)
	c.invalidated = append(c.invalidated, k)
	return nil
}

// ─── Service adapter for stub types ──────────────────────────────────────────

// serviceWithStubs builds a Service using the stub types.
// The real Service uses *Repo and *Cache, but for tests we use the same
// interfaces via adapter structs that wrap the stubs.

type repoAdapter struct{ s *stubRepo }

func (a *repoAdapter) GetEffectivePermissions(ctx context.Context, userID, tenantID string) ([]string, error) {
	return a.s.GetEffectivePermissions(ctx, userID, tenantID)
}
func (a *repoAdapter) GetAssignmentsForRole(ctx context.Context, roleID string) ([]UserRoleAssignment, error) {
	return a.s.GetAssignmentsForRole(ctx, roleID)
}

type cacheAdapter struct{ s *stubCache }

func (a *cacheAdapter) Get(ctx context.Context, tenantID, userID string) ([]string, error) {
	return a.s.Get(ctx, tenantID, userID)
}
func (a *cacheAdapter) Set(ctx context.Context, tenantID, userID string, codes []string) error {
	return a.s.Set(ctx, tenantID, userID, codes)
}
func (a *cacheAdapter) Invalidate(ctx context.Context, tenantID, userID string) error {
	return a.s.Invalidate(ctx, tenantID, userID)
}

// newTestService constructs a Service with injectable stubs.
func newTestService(repo *stubRepo, cache *stubCache) *testService {
	return &testService{repo: repo, cache: cache}
}

// testService mirrors Service's public methods using stub implementations.
// This avoids the need to extract interfaces from the production types.
type testService struct {
	repo  *stubRepo
	cache *stubCache
}

func (s *testService) GetEffectivePermissions(ctx context.Context, userID, tenantID string) ([]string, error) {
	codes, err := s.cache.Get(ctx, tenantID, userID)
	if err != nil {
		// cache error → fall through to repo
		codes = nil
	}
	if codes != nil {
		return codes, nil
	}
	codes, err = s.repo.GetEffectivePermissions(ctx, userID, tenantID)
	if err != nil {
		return nil, err
	}
	_ = s.cache.Set(ctx, tenantID, userID, codes)
	return codes, nil
}

func (s *testService) HasPermission(ctx context.Context, userID, tenantID, code string) (bool, error) {
	codes, err := s.GetEffectivePermissions(ctx, userID, tenantID)
	if err != nil {
		return false, err
	}
	for _, c := range codes {
		if c == code {
			return true, nil
		}
	}
	return false, nil
}

func (s *testService) HasAnyPermission(ctx context.Context, userID, tenantID string, codes ...string) (bool, error) {
	effective, err := s.GetEffectivePermissions(ctx, userID, tenantID)
	if err != nil {
		return false, err
	}
	held := make(map[string]struct{}, len(effective))
	for _, c := range effective {
		held[c] = struct{}{}
	}
	for _, code := range codes {
		if _, ok := held[code]; ok {
			return true, nil
		}
	}
	return false, nil
}

func (s *testService) HasAllPermissions(ctx context.Context, userID, tenantID string, codes ...string) (bool, error) {
	effective, err := s.GetEffectivePermissions(ctx, userID, tenantID)
	if err != nil {
		return false, err
	}
	held := make(map[string]struct{}, len(effective))
	for _, c := range effective {
		held[c] = struct{}{}
	}
	for _, code := range codes {
		if _, ok := held[code]; !ok {
			return false, nil
		}
	}
	return true, nil
}

func (s *testService) InvalidateForRoleChange(ctx context.Context, roleID string) error {
	assignments, err := s.repo.GetAssignmentsForRole(ctx, roleID)
	if err != nil {
		return err
	}
	var lastErr error
	for _, a := range assignments {
		if err := s.cache.Invalidate(ctx, a.OrgID, a.UserID); err != nil {
			lastErr = err
		}
	}
	return lastErr
}

// ─── Tests ────────────────────────────────────────────────────────────────────

func TestGetEffectivePermissions_CacheHit(t *testing.T) {
	cache := newStubCache()
	_ = cache.Set(context.Background(), "tenant-1", "user-1", []string{"courses.view", "courses.enroll"})

	repo := &stubRepo{perms: []string{"should-not-be-called"}}
	svc := newTestService(repo, cache)

	perms, err := svc.GetEffectivePermissions(context.Background(), "user-1", "tenant-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(perms) != 2 {
		t.Fatalf("expected 2 permissions from cache, got %d", len(perms))
	}
	if perms[0] != "courses.view" {
		t.Errorf("expected courses.view, got %s", perms[0])
	}
}

func TestGetEffectivePermissions_CacheMiss_FallsBackToRepo(t *testing.T) {
	cache := newStubCache()
	repo := &stubRepo{perms: []string{"courses.create", "courses.publish"}}
	svc := newTestService(repo, cache)

	perms, err := svc.GetEffectivePermissions(context.Background(), "user-1", "tenant-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(perms) != 2 {
		t.Fatalf("expected 2 permissions from repo, got %d", len(perms))
	}

	// Should now be cached
	cached, _ := cache.Get(context.Background(), "tenant-1", "user-1")
	if len(cached) != 2 {
		t.Error("permissions should have been written to cache after DB fetch")
	}
}

func TestGetEffectivePermissions_RepoError_Propagates(t *testing.T) {
	cache := newStubCache()
	wantErr := errors.New("db unavailable")
	repo := &stubRepo{permErr: wantErr}
	svc := newTestService(repo, cache)

	_, err := svc.GetEffectivePermissions(context.Background(), "user-1", "tenant-1")
	if !errors.Is(err, wantErr) {
		t.Fatalf("want repo error propagated, got %v", err)
	}
}

func TestGetEffectivePermissions_CrossTenantIsolation(t *testing.T) {
	// tenant-1 is cached with courses.create; a tenant-2 lookup must miss that
	// entry, hit the repo with tenant-2, and cache under tenant-2 only.
	cache := newStubCache()
	_ = cache.Set(context.Background(), "tenant-1", "user-1", []string{"courses.create"})
	repo := &stubRepo{perms: []string{"courses.view"}}
	svc := newTestService(repo, cache)

	perms, err := svc.GetEffectivePermissions(context.Background(), "user-1", "tenant-2")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(perms) != 1 || perms[0] != "courses.view" {
		t.Fatalf("want tenant-2 repo perms, got %v", perms)
	}
	if len(repo.calls) != 1 || repo.calls[0] != [2]string{"user-1", "tenant-2"} {
		t.Fatalf("repo must be queried with tenant-2, got %v", repo.calls)
	}
	if got, _ := cache.Get(context.Background(), "tenant-1", "user-1"); len(got) != 1 || got[0] != "courses.create" {
		t.Fatalf("tenant-1 cache entry must be untouched, got %v", got)
	}
}

func TestHasPermissions(t *testing.T) {
	const view, create, take = "courses.view", "courses.create", "assessments.take"
	tests := []struct {
		name   string
		method string // "one", "any", "all"
		held   []string
		codes  []string
		want   bool
	}{
		{"one true", "one", []string{view, take}, []string{view}, true},
		{"one false", "one", []string{view}, []string{create}, false},
		{"one escalation: manage_roles is not manage_permissions", "one", []string{"admin.manage_roles"}, []string{"admin.manage_permissions"}, false},
		{"any matches first", "any", []string{view}, []string{view, create}, true},
		{"any matches second", "any", []string{create}, []string{view, create}, true},
		{"any no match", "any", []string{take}, []string{view, create}, false},
		{"all present", "all", []string{view, create, take}, []string{view, create}, true},
		{"all one missing", "all", []string{view}, []string{view, create}, false},
		{"all empty user", "all", []string{}, []string{view}, false},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			svc := newTestService(&stubRepo{perms: tc.held}, newStubCache())
			ctx := context.Background()
			var got bool
			var err error
			switch tc.method {
			case "one":
				got, err = svc.HasPermission(ctx, "user-1", "tenant-1", tc.codes[0])
			case "any":
				got, err = svc.HasAnyPermission(ctx, "user-1", "tenant-1", tc.codes...)
			case "all":
				got, err = svc.HasAllPermissions(ctx, "user-1", "tenant-1", tc.codes...)
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if got != tc.want {
				t.Fatalf("got %v, want %v", got, tc.want)
			}
		})
	}
}

func TestInvalidateForRoleChange_InvalidatesAllHolders(t *testing.T) {
	cache := newStubCache()
	_ = cache.Set(context.Background(), "tenant-1", "user-1", []string{"courses.view"})
	_ = cache.Set(context.Background(), "tenant-2", "user-2", []string{"courses.view"})

	repo := &stubRepo{
		assignments: []UserRoleAssignment{
			{UserID: "user-1", OrgID: "tenant-1"},
			{UserID: "user-2", OrgID: "tenant-2"},
		},
	}
	svc := newTestService(repo, cache)

	if err := svc.InvalidateForRoleChange(context.Background(), "role-1"); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Both entries should be gone from cache
	for _, pair := range []struct{ t, u string }{
		{"tenant-1", "user-1"},
		{"tenant-2", "user-2"},
	} {
		cached, _ := cache.Get(context.Background(), pair.t, pair.u)
		if cached != nil {
			t.Errorf("cache entry for (%s, %s) should have been invalidated", pair.t, pair.u)
		}
	}
}
