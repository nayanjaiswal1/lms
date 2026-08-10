package mcpconnect

import (
	"context"
	"testing"
)

// ponytail: DB test infra now exists via internal/testdb (see repo_db_test.go
// in this package) — this file predates it and stays pure-Go on purpose,
// covering the one non-DB branch worth a check: isRevertible must never let
// a matched-existing result (create_self_course/add_self_course_module
// resolving to a pre-existing row instead of a new one) come back as
// revertible, since Revert would otherwise delete/soft-delete a row the call
// didn't create.

type fakeMatchedResult struct{ matched bool }

func (r fakeMatchedResult) IsMatchedExisting() bool { return r.matched }

func TestIsRevertible(t *testing.T) {
	toolWithRevert := mcpTool{Revert: func(_ context.Context, _ *Router, _ mcpIdentity, _ ActionLogEntry) error { return nil }}
	toolWithoutRevert := mcpTool{}

	cases := []struct {
		name string
		tool mcpTool
		result any
		want bool
	}{
		{"no revert closure at all", toolWithoutRevert, "anything", false},
		{"revert closure, plain result", toolWithRevert, "some-course-json", true},
		{"revert closure, freshly created", toolWithRevert, fakeMatchedResult{matched: false}, true},
		{"revert closure, matched existing", toolWithRevert, fakeMatchedResult{matched: true}, false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := isRevertible(c.tool, c.result); got != c.want {
				t.Errorf("isRevertible() = %v, want %v", got, c.want)
			}
		})
	}
}
