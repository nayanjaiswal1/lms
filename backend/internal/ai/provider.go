package ai

import (
	"context"
	"errors"
)

// ErrAIDisabled is returned when LLM_PROVIDER=disabled.
var ErrAIDisabled = errors.New("ai: provider disabled")

// LLMProvider is the provider-agnostic interface for all LLM calls.
type LLMProvider interface {
	// Available reports whether the provider is configured and can serve requests.
	Available() bool
	// Complete sends a completion request and returns the response.
	Complete(ctx context.Context, req CompletionRequest) (CompletionResponse, error)
}

// CompletionRequest describes a single LLM request.
type CompletionRequest struct {
	SystemPrompt string
	UserPrompt   string
	MaxTokens    int
	Temperature  float32
	// JSONMode instructs the provider to return valid JSON only.
	JSONMode bool
	// Image, if set, attaches one image alongside UserPrompt as a vision
	// input — used by the captures pipeline to have the model read a
	// screenshot directly instead of running a separate OCR pass.
	Image *ImageInput
}

// ImageInput is a single image attached to a CompletionRequest.
type ImageInput struct {
	// Base64 is the raw base64-encoded image bytes — no "data:" URL prefix.
	Base64 string
	// MediaType is the image's MIME type, e.g. "image/png", "image/jpeg".
	MediaType string
}

// CompletionResponse carries the LLM response and token usage.
type CompletionResponse struct {
	Content string
	Model   string
	Usage   UsageStats
}

// UsageStats reports token consumption for cost tracking.
type UsageStats struct {
	InputTokens  int
	OutputTokens int
}

// NewProvider constructs the LLMProvider selected by provider name.
// provider: "anthropic" | "gemini" | "disabled"
func NewProvider(provider, apiKey, model, baseURL string) LLMProvider {
	switch provider {
	case "anthropic":
		return newAnthropicProvider(apiKey, model)
	case "gemini":
		return newGeminiProvider(apiKey, model, baseURL)
	default:
		return &NoopProvider{}
	}
}
