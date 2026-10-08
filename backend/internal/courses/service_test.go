package courses

import (
	"slices"
	"testing"
)

// ponytail: DB test infra now exists via internal/testdb (see repo_db_test.go
// in this package) — this file predates it and stays pure-Go on purpose,
// covering the one non-DB branch in GetRandomTopic worth a check: the
// fallback tier ordering itself.

func TestRandomTopicAttempts(t *testing.T) {
	type tier struct{ tags, exclude []string }
	interests := []string{"go", "databases"}
	enrolled := []string{"course-1", "course-2"}

	cases := []struct {
		name      string
		interests []string
		exclude   []string
		want      []tier
	}{
		{"with interests, has enrollments", interests, enrolled, []tier{
			{interests, enrolled}, // interest tier
			{nil, enrolled},       // no tag filter, enrolled still excluded
			{nil, nil},            // last resort: no filters
		}},
		{"no stated interests skips the interest tier", nil, enrolled, []tier{
			{nil, enrolled},
			{nil, nil},
		}},
		{"no enrollments yet, has interests", interests, nil, []tier{
			{interests, nil},
			{nil, nil},
			{nil, nil},
		}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			attempts := randomTopicAttempts(tc.interests, tc.exclude)
			if len(attempts) != len(tc.want) {
				t.Fatalf("expected %d tiers, got %d", len(tc.want), len(attempts))
			}
			for i, w := range tc.want {
				// slices.Equal treats nil and empty as equal, which is the intent here.
				if !slices.Equal(attempts[i].Tags, w.tags) || !slices.Equal(attempts[i].ExcludeCourseIDs, w.exclude) {
					t.Errorf("tier %d: got tags %v exclude %v, want tags %v exclude %v",
						i, attempts[i].Tags, attempts[i].ExcludeCourseIDs, w.tags, w.exclude)
				}
			}
		})
	}
}
