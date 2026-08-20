package gitlab

import (
	"strings"
	"testing"
)

func TestBuildReviewPromptSkipsDeletedFiles(t *testing.T) {
	mr := &GitlabMergeRequest{Title: "Add login"}
	changes := []MRChange{
		{NewPath: "old.go", DeletedFile: true, Diff: "should not appear"},
		{NewPath: "new.go", Diff: "+func Login() {}"},
	}
	got := buildReviewPrompt(mr, changes)
	if got == "" {
		t.Fatal("expected non-empty prompt")
	}
	if want := "should not appear"; strings.Contains(got, want) {
		t.Errorf("prompt should skip deleted files, got: %s", got)
	}
	if want := "new.go"; !strings.Contains(got, want) {
		t.Errorf("prompt should include non-deleted file %q, got: %s", want, got)
	}
}

func TestBuildReviewPromptEmptyWhenNothingToReview(t *testing.T) {
	mr := &GitlabMergeRequest{Title: "Delete dead code"}
	changes := []MRChange{{NewPath: "dead.go", DeletedFile: true}}
	if got := buildReviewPrompt(mr, changes); got != "" {
		t.Errorf("expected empty prompt when every change is a deletion, got: %s", got)
	}
}

func TestBuildReviewPromptTruncatesLargeDiff(t *testing.T) {
	big := make([]byte, aiReviewMaxDiffChars+5000)
	for i := range big {
		big[i] = 'a'
	}
	mr := &GitlabMergeRequest{Title: "Huge change"}
	changes := []MRChange{{NewPath: "huge.go", Diff: string(big)}}
	got := buildReviewPrompt(mr, changes)
	if !strings.Contains(got, "(truncated)") {
		t.Errorf("expected truncation marker in prompt for an oversized diff")
	}
	if len(got) > aiReviewMaxDiffChars+500 {
		t.Errorf("prompt length %d not bounded near aiReviewMaxDiffChars=%d", len(got), aiReviewMaxDiffChars)
	}
}
