package highlights

import (
	"strings"
	"testing"
)

func TestComputeHash_ScopedBySourceID(t *testing.T) {
	// Same text and source_type but different source_id (two different lessons)
	// must not collide — otherwise the second lesson's "explain" would silently
	// reuse the first lesson's cached, out-of-context answer.
	a := computeHash("index", "lesson", "lesson-docker-1")
	b := computeHash("index", "lesson", "lesson-sql-1")
	if a == b {
		t.Fatalf("computeHash must differ across source_id, got same hash %q for both", a)
	}

	// Same (text, source_type, source_id) must be stable so repeat selections hit cache.
	c := computeHash("Index", "lesson", "lesson-docker-1")
	if a != c {
		t.Fatalf("computeHash must be case/whitespace-normalized and stable, got %q vs %q", a, c)
	}
}

func TestBuildExplainUserPrompt_IncludesSourceContext(t *testing.T) {
	req := ExplainRequest{
		SourceType:   SourceTypeLesson,
		SourceID:     "lesson-1",
		SelectedText: "index",
	}

	prompt := buildExplainUserPrompt(req)

	if !strings.Contains(prompt, "index") {
		t.Fatalf("prompt must include the highlighted text, got:\n%s", prompt)
	}
}

func TestBuildExplainUserPrompt_WikiPageSource(t *testing.T) {
	req := ExplainRequest{
		SourceType:   SourceTypeWikiPage,
		SourceID:     "page-1",
		SelectedText: "idempotent",
	}

	prompt := buildExplainUserPrompt(req)

	if !strings.Contains(prompt, "idempotent") {
		t.Fatalf("prompt must include the highlighted text, got:\n%s", prompt)
	}
}
