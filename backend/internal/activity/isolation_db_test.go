package activity

import (
	"context"
	"testing"

	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

// The activity feed is read-only. A course completion recorded under org A
// must appear in org A's feed and never in the same user's org B feed.
func TestActivityFeed_OrgScopedCourseCompletion(t *testing.T) {
	pool := testdb.New(t)
	repo := NewRepo(pool)
	ctx := context.Background()

	var orgA, orgB, userID, courseID string
	for slug, dst := range map[string]*string{"act-a": &orgA, "act-b": &orgB} {
		if err := pool.QueryRow(ctx, `INSERT INTO organizations (slug, name) VALUES ($1, $1) RETURNING id`, slug).Scan(dst); err != nil {
			t.Fatalf("seed org %s: %v", slug, err)
		}
	}
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('act@`+testdomain.Domain+`', 'Act') RETURNING id`).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	if err := pool.QueryRow(ctx,
		`INSERT INTO courses (org_id, creator_id, title, slug) VALUES ($1, $2, 'Secret Course', 'secret-course') RETURNING id`,
		orgA, userID).Scan(&courseID); err != nil {
		t.Fatalf("seed course: %v", err)
	}
	if _, err := pool.Exec(ctx,
		`INSERT INTO enrollments (user_id, course_id, completed_at) VALUES ($1, $2, now())`, userID, courseID); err != nil {
		t.Fatalf("seed enrollment: %v", err)
	}

	inA, err := repo.List(ctx, userID, orgA, 0, nil, "", 50)
	if err != nil {
		t.Fatalf("List org A: %v", err)
	}
	if len(inA) != 1 || inA[0].Kind != KindCourseCompleted || inA[0].Title != "Secret Course" {
		t.Fatalf("org A feed = %+v, want the one course_completed entry", inA)
	}
	inB, err := repo.List(ctx, userID, orgB, 0, nil, "", 50)
	if err != nil {
		t.Fatalf("List org B: %v", err)
	}
	if len(inB) != 0 {
		t.Fatalf("org B feed leaked org A activity: %+v", inB)
	}
}
