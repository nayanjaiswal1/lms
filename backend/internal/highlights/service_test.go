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

func TestBuildExplainUserPrompt_IncludesContextSnippet(t *testing.T) {
	snippet := "The reverse index maps content back to the document that produced it."
	req := ExplainRequest{
		SourceType:     SourceTypeLesson,
		SourceID:       "lesson-1",
		SelectedText:   "index",
		ContextSnippet: &snippet,
	}

	prompt := buildExplainUserPrompt(req)

	if !strings.Contains(prompt, snippet) {
		t.Fatalf("prompt must include the captured context snippet, got:\n%s", prompt)
	}
	if !strings.Contains(prompt, "index") {
		t.Fatalf("prompt must include the highlighted text, got:\n%s", prompt)
	}
}

func TestBuildExplainUserPrompt_NoContextSnippet(t *testing.T) {
	req := ExplainRequest{
		SourceType:   SourceTypeWikiPage,
		SourceID:     "page-1",
		SelectedText: "idempotent",
	}

	prompt := buildExplainUserPrompt(req)

	if strings.Contains(prompt, "Surrounding text") {
		t.Fatalf("prompt must not mention surrounding text when no snippet was captured, got:\n%s", prompt)
	}
	if !strings.Contains(prompt, "idempotent") {
		t.Fatalf("prompt must include the highlighted text, got:\n%s", prompt)
	}
}
