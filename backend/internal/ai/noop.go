package ai

import "context"

// NoopProvider is returned when LLM_PROVIDER=disabled.
// All calls return ErrAIDisabled so callers can gate on Available() first.
type NoopProvider struct{}

func (n *NoopProvider) Available() bool { return false }

func (n *NoopProvider) Complete(_ context.Context, _ CompletionRequest) (CompletionResponse, error) {
	return CompletionResponse{}, ErrAIDisabled
}
