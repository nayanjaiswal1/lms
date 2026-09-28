package courses

import (
	"context"
	"testing"

	"github.com/mindforge/backend/internal/testdb"
)

// TestForkCourse_KeepsLabLink is the regression check for the bug
// docs/debug-labs.md L0 describes: ForkCourse (via copySectionsAndModules)
// used to copy every course_modules column except lab_id, so a forked lab
// module resolved no lab at all. It now copies lab_id/lab_is_required
// straight across — a forked lab module still points at the SAME
// lab_definitions row as the original (labs are referenced, not copied; see
// docs/debug-labs.md L1).
func TestForkCourse_KeepsLabLink(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)

	orgID, userID, courseID := seedCourseFixture(t, ctx, pool)

	section, err := repo.CreateSection(ctx, CourseSection{CourseID: courseID, Title: "Section"})
	if err != nil {
		t.Fatalf("CreateSection: %v", err)
	}

	var labID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO lab_definitions (org_id, title, lab_type, environment, is_published, created_by, library_visibility)
		 VALUES ($1,'Lab','terminal','mindforge/lab-terminal:1',true,$2,'org') RETURNING id`,
		orgID, userID,
	).Scan(&labID); err != nil {
		t.Fatalf("seed lab: %v", err)
	}

	if _, err := pool.Exec(ctx,
		`INSERT INTO course_modules (course_id, section_id, title, type, position, lab_id, lab_is_required)
		 VALUES ($1,$2,'Lab Module','lab',0,$3,true)`,
		courseID, section.ID, labID,
	); err != nil {
		t.Fatalf("seed lab module: %v", err)
	}

	forked, err := repo.ForkCourse(ctx, orgID, courseID, userID, "Course (fork)", "course-fork")
	if err != nil {
		t.Fatalf("ForkCourse: %v", err)
	}

	var gotLabID string
	var gotRequired bool
	if err := pool.QueryRow(ctx,
		`SELECT lab_id, lab_is_required FROM course_modules WHERE course_id=$1 AND type='lab'`,
		forked.ID,
	).Scan(&gotLabID, &gotRequired); err != nil {
		t.Fatalf("query forked module: %v", err)
	}
	if gotLabID != labID {
		t.Errorf("forked lab module lab_id = %q, want %q (the original lab — labs are referenced, not copied)", gotLabID, labID)
	}
	if !gotRequired {
		t.Error("forked lab module lab_is_required = false, want true (copied from the original placement)")
	}
}
