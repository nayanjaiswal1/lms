package features_test

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/features"
	"github.com/stretchr/testify/require"
)

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

func TestResolve_GrantedFeatureIsEntitled(t *testing.T) {
	pool := setupTestDB(t)
	ctx := context.Background()

	email := fmt.Sprintf("features-test-%d@mindforge.dev", time.Now().UnixNano())
	userID := createTestUser(t, pool, email)

	_, err := pool.Exec(ctx,
		`INSERT INTO feature_grants (user_id, feature_key) VALUES ($1, 'what_now')`,
		userID,
	)
	require.NoError(t, err)

	service := features.NewService(features.NewRepo(pool))
	cfg, err := service.Resolve(ctx, userID, "")
	require.NoError(t, err)

	require.Contains(t, cfg.OrgFeatures, "what_now")
	require.Contains(t, cfg.Entitlements, "what_now")
}

func TestResolve_UngrantedUserIsNotEntitled(t *testing.T) {
	pool := setupTestDB(t)
	ctx := context.Background()

	email := fmt.Sprintf("features-test-%d@mindforge.dev", time.Now().UnixNano())
	userID := createTestUser(t, pool, email)

	service := features.NewService(features.NewRepo(pool))
	cfg, err := service.Resolve(ctx, userID, "")
	require.NoError(t, err)

	require.Contains(t, cfg.OrgFeatures, "what_now")
	require.NotContains(t, cfg.Entitlements, "what_now")
}
