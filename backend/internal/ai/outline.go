package ai

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
)

// Course-outline generation runs in two places: the instructor's sync preview
// endpoint (which returns the outline for review and writes nothing) and the
// llm.task job that persists it. Both used to hand-roll the same defaults,
// clamps, prompt and model call, so changing the module cap in one made the
// preview silently disagree with what the job would actually produce. Every
// decision they share lives here.

const (
	// DefaultOutlineLevel is the difficulty used when the caller supplies none.
	DefaultOutlineLevel = "intermediate"
	// DefaultOutlineModuleCount is used when the caller asks for no (or a
	// non-positive) number of modules.
	DefaultOutlineModuleCount = 8
	// MaxOutlineModuleCount caps the module count — the model is prompted with
	// this many, so raising it must happen in exactly one place.
	MaxOutlineModuleCount = 30
	// MaxOutlineTopicChars bounds the topic line after sanitisation, so a
	// pasted job description cannot blow up the prompt.
	MaxOutlineTopicChars = 200

	outlineMaxTokens = 2048
)

var (
	// ErrOutlineTopicRequired means the topic was empty once sanitised.
	ErrOutlineTopicRequired = errors.New("ai: outline topic is required")
	// ErrOutlineUnparsable means the model returned something that is not a
	// course outline — callers distinguish it from a transport failure.
	ErrOutlineUnparsable = errors.New("ai: outline response was not valid JSON")
)

// OutlineParams are the model-facing inputs to outline generation.
type OutlineParams struct {
	Topic       string
	Level       string
	ModuleCount int
}

// Normalize applies the shared defaults and clamps. It is the only place the
// default level, default module count and module cap are decided.
func (p OutlineParams) Normalize() (OutlineParams, error) {
	p.Topic = SanitizeTopic(p.Topic, MaxOutlineTopicChars)
	if p.Topic == "" {
		return OutlineParams{}, ErrOutlineTopicRequired
	}
	if p.Level == "" {
		p.Level = DefaultOutlineLevel
	}
	if p.ModuleCount <= 0 {
		p.ModuleCount = DefaultOutlineModuleCount
	}
	if p.ModuleCount > MaxOutlineModuleCount {
		p.ModuleCount = MaxOutlineModuleCount
	}
	return p, nil
}

// CourseOutline is the structure CourseOutlineSystemPrompt is instructed to
// emit. It doubles as the preview endpoint's response body, so field tags
// double as the public JSON contract.
type CourseOutline struct {
	Title       string                 `json:"title"`
	Description string                 `json:"description"`
	Sections    []CourseOutlineSection `json:"sections"`
}

type CourseOutlineSection struct {
	Title      string                `json:"title"`
	GroupTitle *string               `json:"group_title"`
	Modules    []CourseOutlineModule `json:"modules"`
}

type CourseOutlineModule struct {
	Title            string `json:"title"`
	Type             string `json:"type"`
	Description      string `json:"description"`
	EstimatedMinutes int    `json:"estimated_minutes"`
}

// OutlineUserPrompt renders the user prompt for a normalised parameter set.
func OutlineUserPrompt(p OutlineParams) string {
	return fmt.Sprintf("Topic: %s\nDifficulty: %s\nNumber of modules: %d", p.Topic, p.Level, p.ModuleCount)
}

// GenerateOutline normalizes p, calls the provider once and parses the reply.
// It performs no persistence — callers decide what to do with the result.
// The returned string is the model that produced the outline.
func GenerateOutline(ctx context.Context, provider LLMProvider, p OutlineParams) (CourseOutline, string, error) {
	normalized, err := p.Normalize()
	if err != nil {
		return CourseOutline{}, "", err
	}

	resp, err := provider.Complete(ctx, CompletionRequest{
		SystemPrompt: CourseOutlineSystemPrompt,
		UserPrompt:   OutlineUserPrompt(normalized),
		MaxTokens:    outlineMaxTokens,
		JSONMode:     true,
	})
	if err != nil {
		return CourseOutline{}, "", err
	}

	var outline CourseOutline
	if err := json.Unmarshal([]byte(resp.Content), &outline); err != nil {
		return CourseOutline{}, "", fmt.Errorf("%w: %w", ErrOutlineUnparsable, err)
	}
	return outline, resp.Model, nil
}
