package courses

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/testdb"
)

// seedPublicCourseFixture inserts one org/user plus a course row the caller
// controls status/is_public on, so tests can exercise every combination of
// the anonymous-visibility gate (docs/anonymous.md).
func seedPublicCourseFixture(t *testing.T, ctx context.Context, pool *pgxpool.Pool, slug, status string, isPublic bool) (courseID string) {
	t.Helper()

	var orgID, userID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO organizations (slug, name) VALUES ($1, 'Acme Corp') RETURNING id`, "org-"+slug,
	).Scan(&orgID); err != nil {
		t.Fatalf("seed org: %v", err)
	}
	if err := pool.QueryRow(ctx,
		`INSERT INTO users (email, name) VALUES ($1, 'Instructor') RETURNING id`, slug+"@example.com",
	).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	if err := pool.QueryRow(ctx,
		`INSERT INTO courses (org_id, creator_id, title, slug, status, is_public) VALUES ($1, $2, 'Public Course', $3, $4, $5) RETURNING id`,
		orgID, userID, slug, status, isPublic,
	).Scan(&courseID); err != nil {
		t.Fatalf("seed course: %v", err)
	}
	return courseID
}

// TestGetPublicCourseTreeBySlug exercises the anonymous course-learning
// endpoint's access gate directly against the database — the one place a
// mistake would leak a draft or private course to an unauthenticated visitor.
func TestGetPublicCourseTreeBySlug(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)

	t.Run("published and is_public is visible with its tree", func(t *testing.T) {
		courseID := seedPublicCourseFixture(t, ctx, pool, "visible-course", "published", true)
		var sectionID string
		if err := pool.QueryRow(ctx,
			`INSERT INTO course_sections (course_id, title, position) VALUES ($1, 'Intro', 0) RETURNING id`, courseID,
		).Scan(&sectionID); err != nil {
			t.Fatalf("seed section: %v", err)
		}
		if _, err := pool.Exec(ctx,
			`INSERT INTO course_modules (course_id, section_id, title, type, content_body) VALUES ($1, $2, 'Lesson 1', 'notes', 'hello')`,
			courseID, sectionID,
		); err != nil {
			t.Fatalf("seed module: %v", err)
		}

		tree, err := repo.GetPublicCourseTreeBySlug(ctx, "visible-course")
		if err != nil {
			t.Fatalf("GetPublicCourseTreeBySlug: %v", err)
		}
		if tree.ID != courseID {
			t.Errorf("expected course id %q, got %q", courseID, tree.ID)
		}
		if len(tree.Sections) != 1 || len(tree.Sections[0].Modules) != 1 {
			t.Fatalf("expected 1 section with 1 module, got %+v", tree.Sections)
		}
		if got := tree.Sections[0].Modules[0].ContentBody; got == nil || *got != "hello" {
			t.Errorf("expected module content_body 'hello', got %v", got)
		}
	})

	t.Run("published but not is_public is not visible", func(t *testing.T) {
		seedPublicCourseFixture(t, ctx, pool, "private-course", "published", false)

		if _, err := repo.GetPublicCourseTreeBySlug(ctx, "private-course"); err != ErrNotFound {
			t.Fatalf("expected ErrNotFound, got %v", err)
		}
	})

	t.Run("is_public but still a draft is not visible", func(t *testing.T) {
		seedPublicCourseFixture(t, ctx, pool, "draft-course", "draft", true)

		if _, err := repo.GetPublicCourseTreeBySlug(ctx, "draft-course"); err != ErrNotFound {
			t.Fatalf("expected ErrNotFound, got %v", err)
		}
	})

	t.Run("unknown slug is not visible", func(t *testing.T) {
		if _, err := repo.GetPublicCourseTreeBySlug(ctx, "does-not-exist"); err != ErrNotFound {
			t.Fatalf("expected ErrNotFound, got %v", err)
		}
	})
}
