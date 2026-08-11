package courses

import (
	"context"
	"fmt"
	"sync"
	"testing"

	"github.com/mindforge/backend/internal/testdb"
)

// TestCreateModule_ConcurrentInsertsGetUniquePositions is the regression
// check for the race that let two concurrent CreateModule calls into the
// same section both compute the same MAX(position)+1 and collide on the
// deferred course_modules_section_id_position_key constraint at commit
// (migration 013's course_modules_lock_section_trigger). Every writer path
// funnels through this same trigger, so exercising it via CreateModule
// covers the fix for all of them.
func TestCreateModule_ConcurrentInsertsGetUniquePositions(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)

	_, _, courseID := seedProposalFixture(t, ctx, pool)
	section, err := repo.CreateSection(ctx, CourseSection{CourseID: courseID, Title: "Intro"})
	if err != nil {
		t.Fatalf("CreateSection: %v", err)
	}

	const n = 20
	var wg sync.WaitGroup
	errs := make(chan error, n)
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			_, err := repo.CreateModule(ctx, CourseModule{
				CourseID:  courseID,
				SectionID: section.ID,
				Title:     fmt.Sprintf("Module %d", i),
				Type:      ModuleTypeNotes,
			})
			if err != nil {
				errs <- err
			}
		}(i)
	}
	wg.Wait()
	close(errs)
	for err := range errs {
		t.Errorf("CreateModule: %v", err)
	}

	rows, err := pool.Query(ctx,
		`SELECT position FROM course_modules WHERE section_id=$1 AND deleted_at IS NULL ORDER BY position`, section.ID)
	if err != nil {
		t.Fatalf("query positions: %v", err)
	}
	defer rows.Close()

	seen := map[int]bool{}
	count := 0
	for rows.Next() {
		var pos int
		if err := rows.Scan(&pos); err != nil {
			t.Fatalf("scan position: %v", err)
		}
		if seen[pos] {
			t.Fatalf("duplicate position %d assigned to two modules", pos)
		}
		seen[pos] = true
		count++
	}
	if count != n {
		t.Fatalf("expected %d modules, found %d", n, count)
	}
}
