package features_test

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/entitlements"
	"github.com/mindforge/backend/internal/features"
	"github.com/stretchr/testify/require"
)

// newTestService builds a features.Service backed by a real entitlements.Service
// over the same pool — defaultOrgID "" means every test org here resolves to
// the org axis (never the individual/DefaultOrgID axis), matching what these
// tests actually exercise (org_feature_flags/user_feature_flags/grants).
func newTestService(pool *pgxpool.Pool) *features.Service {
	return features.NewService(features.NewRepo(pool), entitlements.NewService(entitlements.NewRepo(pool), ""))
}

func setupTestDB(t *testing.T) *pgxpool.Pool {
	t.Helper()
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set")
	}
	pool, err := pgxpool.New(context.Background(), dsn)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	t.Cleanup(func() { pool.Close() })
	return pool
}

// createTestOrg inserts a minimal org and registers cleanup. Returns the org UUID.
func createTestOrg(t *testing.T, pool *pgxpool.Pool, slug string) string {
	t.Helper()
	var id string
	err := pool.QueryRow(context.Background(),
		`INSERT INTO organizations (slug, name) VALUES ($1, 'Test Org') RETURNING id`,
		slug,
	).Scan(&id)
	require.NoError(t, err)

	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM organizations WHERE id = $1`, id) //nolint:errcheck
	})
	return id
}

// createTestUser inserts a minimal user and registers cleanup. Returns the user UUID.
func createTestUser(t *testing.T, pool *pgxpool.Pool, email string) string {
	t.Helper()
	var id string
	err := pool.QueryRow(context.Background(),
		`INSERT INTO users (email, name) VALUES ($1, 'Test User') RETURNING id`,
		email,
	).Scan(&id)
	require.NoError(t, err)

	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM users WHERE id = $1`, id) //nolint:errcheck
	})
	return id
}

// grantFeature inserts a "features.<key>" permission override for userID,
// mirroring what the RBAC admin UI does for what_now/revision_digest grants.
func grantFeature(t *testing.T, pool *pgxpool.Pool, orgID, userID, featureKey string) {
	t.Helper()
	var permissionID string
	err := pool.QueryRow(context.Background(),
		`SELECT id FROM permissions WHERE code = $1`, "features."+featureKey,
	).Scan(&permissionID)
	require.NoError(t, err)

	_, err = pool.Exec(context.Background(),
		`INSERT INTO user_permission_overrides (user_id, org_id, permission_id) VALUES ($1, $2, $3)`,
		userID, orgID, permissionID,
	)
	require.NoError(t, err)
}

func TestResolve_GrantedFeatureIsEntitled(t *testing.T) {
	pool := setupTestDB(t)
	ctx := context.Background()

	email := fmt.Sprintf("features-test-%d@mindforge.dev", time.Now().UnixNano())
	userID := createTestUser(t, pool, email)
	orgID := createTestOrg(t, pool, fmt.Sprintf("features-test-%d", time.Now().UnixNano()))
	grantFeature(t, pool, orgID, userID, "what_now")

	service := newTestService(pool)
	cfg, err := service.Resolve(ctx, userID, orgID)
	require.NoError(t, err)

	require.Contains(t, cfg.OrgFeatures, "what_now")
	require.Contains(t, cfg.Entitlements, "what_now")
}

func TestResolve_UngrantedUserIsNotEntitled(t *testing.T) {
	pool := setupTestDB(t)
	ctx := context.Background()

	email := fmt.Sprintf("features-test-%d@mindforge.dev", time.Now().UnixNano())
	userID := createTestUser(t, pool, email)
	orgID := createTestOrg(t, pool, fmt.Sprintf("features-test-%d", time.Now().UnixNano()))

	service := newTestService(pool)
	cfg, err := service.Resolve(ctx, userID, orgID)
	require.NoError(t, err)

	require.Contains(t, cfg.OrgFeatures, "what_now")
	require.NotContains(t, cfg.Entitlements, "what_now")
}

func TestResolve_OrgAdminCanDisableFeatureOrgWide(t *testing.T) {
	pool := setupTestDB(t)
	ctx := context.Background()

	email := fmt.Sprintf("features-test-%d@mindforge.dev", time.Now().UnixNano())
	userID := createTestUser(t, pool, email)
	orgID := createTestOrg(t, pool, fmt.Sprintf("features-test-%d", time.Now().UnixNano()))

	service := newTestService(pool)
	require.NoError(t, service.SetOrgFeatureFlag(ctx, orgID, "wiki", false, userID))

	cfg, err := service.Resolve(ctx, userID, orgID)
	require.NoError(t, err)
	require.NotContains(t, cfg.OrgFeatures, "wiki")
	require.NotContains(t, cfg.Entitlements, "wiki")
}

func TestResolve_OrgAdminCanRevokeFeaturePerUser(t *testing.T) {
	pool := setupTestDB(t)
	ctx := context.Background()

	email := fmt.Sprintf("features-test-%d@mindforge.dev", time.Now().UnixNano())
	userID := createTestUser(t, pool, email)
	orgID := createTestOrg(t, pool, fmt.Sprintf("features-test-%d", time.Now().UnixNano()))
	_, err := pool.Exec(ctx,
		`INSERT INTO org_members (org_id, user_id, role, status) VALUES ($1, $2, 'learner', 'active')`,
		orgID, userID,
	)
	require.NoError(t, err)

	service := newTestService(pool)
	require.NoError(t, service.SetUserFeatureFlag(ctx, orgID, userID, "wiki", false, userID))

	cfg, err := service.Resolve(ctx, userID, orgID)
	require.NoError(t, err)
	require.Contains(t, cfg.OrgFeatures, "wiki")
	require.NotContains(t, cfg.Entitlements, "wiki")
}

func TestSetUserFeatureFlag_RejectsFeatureOrgHasNotEnabled(t *testing.T) {
	pool := setupTestDB(t)
	ctx := context.Background()

	email := fmt.Sprintf("features-test-%d@mindforge.dev", time.Now().UnixNano())
	userID := createTestUser(t, pool, email)
	orgID := createTestOrg(t, pool, fmt.Sprintf("features-test-%d", time.Now().UnixNano()))
	_, err := pool.Exec(ctx,
		`INSERT INTO org_members (org_id, user_id, role, status) VALUES ($1, $2, 'learner', 'active')`,
		orgID, userID,
	)
	require.NoError(t, err)

	service := newTestService(pool)
	require.NoError(t, service.SetOrgFeatureFlag(ctx, orgID, "wiki", false, userID))

	err = service.SetUserFeatureFlag(ctx, orgID, userID, "wiki", true, userID)
	require.ErrorIs(t, err, features.ErrFeatureNotOrgEnabled)
}
