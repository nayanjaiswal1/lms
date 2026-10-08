package labs

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/mindforge/backend/internal/labkinds"
)

// Debug labs must complete on finish (optional write-up), not on the last
// required pass; kind-less labs keep the required-pass policy.
func TestCompletionPolicy_DebugFinishOthersRequiredPass(t *testing.T) {
	s := &Service{}
	if got := s.completionPolicy(&LabDefinition{LabType: "debug"}); got != labkinds.CompleteOnFinish {
		t.Fatalf("debug lab policy = %q, want %q", got, labkinds.CompleteOnFinish)
	}
	if got := s.completionPolicy(&LabDefinition{LabType: "code"}); got != labkinds.CompleteOnRequiredPass {
		t.Fatalf("kind-less lab policy = %q, want %q", got, labkinds.CompleteOnRequiredPass)
	}
}

// A *RateLimitedError (even wrapped) must map to 429 with a Retry-After header.
func TestWriteDomainError_RateLimitedSetsRetryAfter(t *testing.T) {
	rec := httptest.NewRecorder()
	writeDomainError(rec, fmt.Errorf("grade: %w", &RateLimitedError{RetryAfter: 7 * time.Second}))
	if rec.Code != http.StatusTooManyRequests {
		t.Fatalf("status = %d, want 429", rec.Code)
	}
	if got := rec.Header().Get("Retry-After"); got != "7" {
		t.Fatalf("Retry-After = %q, want 7", got)
	}
}
