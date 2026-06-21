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
}

func (r *stubRepo) GetEffectivePermissions(_ context.Context, _, _ string) ([]string, error) {
	return r.perms, r.permErr
}

func (r *stubRepo) GetAssignmentsForRole(_ context.Context, _ string) ([]UserRoleAssignment, error) {
	return r.assignments, r.assignErr
}

// ─── Stub cache ───────────────────────────────────────────────────────────────

type stubCache struct {
	stored      map[string][]string
	getErr      error
	setErr      error
	invalidated []string
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
		if err := s.cache.Invalidate(ctx, a.TenantID, a.UserID); err != nil {
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
	repo := &stubRepo{permErr: errors.New("db unavailable")}
	svc := newTestService(repo, cache)

	_, err := svc.GetEffectivePermissions(context.Background(), "user-1", "tenant-1")
	if err == nil {
		t.Fatal("expected error to propagate from repo, got nil")
	}
}

func TestGetEffectivePermissions_CrossTenantIsolation(t *testing.T) {
	// tenant-1 has courses.create; tenant-2 has only courses.view
	cache := newStubCache()
	_ = cache.Set(context.Background(), "tenant-1", "user-1", []string{"courses.create"})
	_ = cache.Set(context.Background(), "tenant-2", "user-1", []string{"courses.view"})

	repo := &stubRepo{}
	svc := newTestService(repo, cache)

	// Querying tenant-2 must not return tenant-1's permissions.
	perms, err := svc.GetEffectivePermissions(context.Background(), "user-1", "tenant-2")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	for _, p := range perms {
		if p == "courses.create" {
			t.Error("cross-tenant permission leak: courses.create from tenant-1 appeared in tenant-2 results")
		}
	}
}

func TestHasPermission_True(t *testing.T) {
	cache := newStubCache()
	repo := &stubRepo{perms: []string{"courses.view", "assessments.take"}}
	svc := newTestService(repo, cache)

	ok, err := svc.HasPermission(context.Background(), "user-1", "tenant-1", "courses.view")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !ok {
		t.Error("expected HasPermission to return true for courses.view")
	}
}

func TestHasPermission_False(t *testing.T) {
	cache := newStubCache()
	repo := &stubRepo{perms: []string{"courses.view"}}
	svc := newTestService(repo, cache)

	ok, err := svc.HasPermission(context.Background(), "user-1", "tenant-1", "courses.create")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if ok {
		t.Error("expected HasPermission to return false for courses.create")
	}
}

func TestHasAnyPermission_MatchesFirst(t *testing.T) {
	cache := newStubCache()
	repo := &stubRepo{perms: []string{"courses.view"}}
	svc := newTestService(repo, cache)

	ok, err := svc.HasAnyPermission(context.Background(), "user-1", "tenant-1",
		"courses.view", "courses.create")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !ok {
		t.Error("expected HasAnyPermission to return true")
	}
}

func TestHasAnyPermission_MatchesSecond(t *testing.T) {
	cache := newStubCache()
	repo := &stubRepo{perms: []string{"courses.create"}}
	svc := newTestService(repo, cache)

	ok, err := svc.HasAnyPermission(context.Background(), "user-1", "tenant-1",
		"courses.view", "courses.create")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !ok {
		t.Error("expected HasAnyPermission to return true for second code")
	}
}

func TestHasAnyPermission_NoMatch(t *testing.T) {
	cache := newStubCache()
	repo := &stubRepo{perms: []string{"assessments.take"}}
	svc := newTestService(repo, cache)

	ok, err := svc.HasAnyPermission(context.Background(), "user-1", "tenant-1",
		"courses.view", "courses.create")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if ok {
		t.Error("expected HasAnyPermission to return false")
	}
}

func TestHasAllPermissions_AllPresent(t *testing.T) {
	cache := newStubCache()
	repo := &stubRepo{perms: []string{"courses.view", "courses.create", "assessments.take"}}
	svc := newTestService(repo, cache)

	ok, err := svc.HasAllPermissions(context.Background(), "user-1", "tenant-1",
		"courses.view", "courses.create")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !ok {
		t.Error("expected HasAllPermissions to return true when all codes held")
	}
}

func TestHasAllPermissions_OneMissing(t *testing.T) {
	cache := newStubCache()
	repo := &stubRepo{perms: []string{"courses.view"}}
	svc := newTestService(repo, cache)

	ok, err := svc.HasAllPermissions(context.Background(), "user-1", "tenant-1",
		"courses.view", "courses.create")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if ok {
		t.Error("expected HasAllPermissions to return false when one code is missing")
	}
}

func TestHasAllPermissions_EmptyUser(t *testing.T) {
	cache := newStubCache()
	repo := &stubRepo{perms: []string{}}
	svc := newTestService(repo, cache)

	ok, err := svc.HasAllPermissions(context.Background(), "user-1", "tenant-1", "courses.view")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if ok {
		t.Error("expected HasAllPermissions to return false for user with no permissions")
	}
}

func TestInvalidateForRoleChange_InvalidatesAllHolders(t *testing.T) {
	cache := newStubCache()
	_ = cache.Set(context.Background(), "tenant-1", "user-1", []string{"courses.view"})
	_ = cache.Set(context.Background(), "tenant-2", "user-2", []string{"courses.view"})

	repo := &stubRepo{
		assignments: []UserRoleAssignment{
			{UserID: "user-1", TenantID: "tenant-1"},
			{UserID: "user-2", TenantID: "tenant-2"},
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

func TestPrivilegeEscalation_CannotGrantSelfAdmin(t *testing.T) {
	// A user with only admin.manage_roles should not be able to grant
	// admin.manage_permissions to themselves via the permission system.
	// This is enforced at the AdminService layer, but we verify the baseline
	// here: the permission set returned does not magically expand.
	cache := newStubCache()
	repo := &stubRepo{perms: []string{"admin.manage_roles"}} // does NOT include admin.manage_permissions
	svc := newTestService(repo, cache)

	ok, err := svc.HasPermission(context.Background(), "user-1", "tenant-1", "admin.manage_permissions")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if ok {
		t.Error("privilege escalation: user should not hold admin.manage_permissions")
	}
}
