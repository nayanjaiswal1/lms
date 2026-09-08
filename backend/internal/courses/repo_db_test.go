package courses

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/testdb"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

// seedCourseFixture inserts the minimum org/user/course rows a DB-backed
// courses test needs — organizations.slug/name, users.email/name, and
// courses.org_id/creator_id/title/slug all have NOT NULL or CHECK
// constraints that a bare INSERT would trip.
func seedCourseFixture(t *testing.T, ctx context.Context, pool *pgxpool.Pool) (orgID, userID, courseID string) {
	t.Helper()

	if err := pool.QueryRow(ctx,
		`INSERT INTO organizations (slug, name) VALUES ('acme-corp', 'Acme Corp') RETURNING id`,
	).Scan(&orgID); err != nil {
		t.Fatalf("seed org: %v", err)
	}
	if err := pool.QueryRow(ctx,
		`INSERT INTO users (email, name) VALUES ('proposer@example.com', 'Proposer') RETURNING id`,
	).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	if err := pool.QueryRow(ctx,
		`INSERT INTO courses (org_id, creator_id, title, slug) VALUES ($1, $2, 'Target Course', 'target-course') RETURNING id`,
		orgID, userID,
	).Scan(&courseID); err != nil {
		t.Fatalf("seed course: %v", err)
	}
	return orgID, userID, courseID
}
