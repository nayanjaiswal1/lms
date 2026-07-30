package courses

import "testing"

// ponytail: no DB test infra exists for domain packages yet (see
// roadmap.service_test.go's precedent) — this covers the one pure-Go branch
// in GetRandomTopic worth a check: the fallback tier ordering itself.

func TestRandomTopicAttempts(t *testing.T) {
	interests := []string{"go", "databases"}
	exclude := []string{"course-1", "course-2"}

	t.Run("with interests, has enrollments", func(t *testing.T) {
		attempts := randomTopicAttempts(interests, exclude)
		if len(attempts) != 3 {
			t.Fatalf("expected 3 tiers, got %d", len(attempts))
		}
		if len(attempts[0].Tags) != 2 || attempts[0].Tags[0] != "go" {
			t.Errorf("tier 0: expected interest tags, got %v", attempts[0].Tags)
		}
		if len(attempts[0].ExcludeCourseIDs) != 2 {
			t.Errorf("tier 0: expected enrolled courses excluded, got %v", attempts[0].ExcludeCourseIDs)
		}
		if len(attempts[1].Tags) != 0 {
			t.Errorf("tier 1: expected no tag filter, got %v", attempts[1].Tags)
		}
		if len(attempts[1].ExcludeCourseIDs) != 2 {
			t.Errorf("tier 1: expected enrolled courses still excluded, got %v", attempts[1].ExcludeCourseIDs)
		}
		if len(attempts[2].Tags) != 0 || len(attempts[2].ExcludeCourseIDs) != 0 {
			t.Errorf("tier 2 (last-resort): expected no filters at all, got %+v", attempts[2])
		}
	})

	t.Run("no stated interests skips the interest tier", func(t *testing.T) {
		attempts := randomTopicAttempts(nil, exclude)
		if len(attempts) != 2 {
			t.Fatalf("expected 2 tiers when there are no interests, got %d", len(attempts))
		}
		if len(attempts[0].Tags) != 0 {
			t.Errorf("tier 0: expected no tag filter without stated interests, got %v", attempts[0].Tags)
		}
		if len(attempts[0].ExcludeCourseIDs) != 2 {
			t.Errorf("tier 0: expected enrolled courses excluded, got %v", attempts[0].ExcludeCourseIDs)
		}
		if len(attempts[1].ExcludeCourseIDs) != 0 {
			t.Errorf("tier 1 (last-resort): expected no exclusion, got %v", attempts[1].ExcludeCourseIDs)
		}
	})

	t.Run("no enrollments yet, has interests", func(t *testing.T) {
		attempts := randomTopicAttempts(interests, nil)
		if len(attempts) != 3 {
			t.Fatalf("expected 3 tiers, got %d", len(attempts))
		}
		if len(attempts[0].ExcludeCourseIDs) != 0 {
			t.Errorf("tier 0: expected no exclusion for a student with no enrollments, got %v", attempts[0].ExcludeCourseIDs)
		}
	})
}
