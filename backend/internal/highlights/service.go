package highlights

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/ai"
)

var (
	ErrAIUnavailable    = errors.New("highlights: AI provider not available")
	ErrInvalidSource    = errors.New("highlights: invalid source type")
	ErrTextTooShort     = errors.New("highlights: selected text must be at least 3 characters")
	ErrTextTooLong      = errors.New("highlights: selected text exceeds 2000 characters")
)

// Service holds the highlight domain's business logic.
type Service struct {
	repo     *Repo
	provider ai.LLMProvider
}

func NewService(repo *Repo, provider ai.LLMProvider) *Service {
	return &Service{repo: repo, provider: provider}
}

// Create saves a user's text selection without generating an explanation.
// Used when the user clicks "Save for revision" before or instead of "Explain now".
func (s *Service) Create(ctx context.Context, userID string, req CreateRequest) (Highlight, error) {
	if err := validateRequest(req.SourceType, req.SelectedText); err != nil {
		return Highlight{}, err
	}
	textHash := computeHash(req.SelectedText, string(req.SourceType))
	return s.repo.Create(ctx, userID, textHash, req)
}

// Explain creates a highlight record and returns an AI explanation for the selected text.
// The explanation is served from cache when the same (text, source_type) has been
// explained before; otherwise the LLM is called and the result is cached.
func (s *Service) Explain(ctx context.Context, userID string, req ExplainRequest) (ExplainResponse, error) {
	if err := validateRequest(req.SourceType, req.SelectedText); err != nil {
		return ExplainResponse{}, err
	}

	textHash := computeHash(req.SelectedText, string(req.SourceType))

	h, err := s.repo.Create(ctx, userID, textHash, CreateRequest{
		SourceType:     req.SourceType,
		SourceID:       req.SourceID,
		SelectedText:   req.SelectedText,
		PositionStart:  req.PositionStart,
		PositionEnd:    req.PositionEnd,
		ContextSnippet: req.ContextSnippet,
		SourceURL:      req.SourceURL,
	})
	if err != nil {
		return ExplainResponse{}, err
	}

	existing, found, err := s.repo.GetExplanationByHash(ctx, textHash)
	if err != nil {
		return ExplainResponse{}, err
	}
	if found {
		if err := s.repo.IncrementServeCount(ctx, textHash); err != nil {
			return ExplainResponse{}, err
		}
		existing.ServeCount++
		existing.FromCache = true
		return ExplainResponse{HighlightID: h.ID, Explanation: &existing}, nil
	}

	if !s.provider.Available() {
		return ExplainResponse{}, ErrAIUnavailable
	}

	userPrompt := fmt.Sprintf(
		"Context: this text appears in a %s.\n\nHighlighted text:\n%s",
		sourceLabel(req.SourceType),
		ai.SanitizeTopic(req.SelectedText, 2000),
	)

	resp, err := s.provider.Complete(ctx, ai.CompletionRequest{
		SystemPrompt: ai.HighlightExplainSystemPrompt,
		UserPrompt:   userPrompt,
		MaxTokens:    300,
		Temperature:  0.3,
	})
	if err != nil {
		return ExplainResponse{}, fmt.Errorf("highlights: call AI: %w", err)
	}

	explanation, err := s.repo.InsertExplanation(ctx, textHash, req.SelectedText, string(req.SourceType), resp.Content, resp.Model)
	if err != nil {
		return ExplainResponse{}, err
	}
	explanation.FromCache = false

	return ExplainResponse{HighlightID: h.ID, Explanation: &explanation}, nil
}

// GetForSource returns a user's highlights for a specific content resource,
// with cached explanations joined in. Used by the "see all highlights" panel.
func (s *Service) GetForSource(ctx context.Context, userID string, sourceType SourceType, sourceID string) ([]Highlight, error) {
	if !validSourceType(sourceType) {
		return nil, ErrInvalidSource
	}
	return s.repo.ListBySource(ctx, userID, string(sourceType), sourceID)
}

// ToggleRevision flips the saved_for_revision flag on a user-owned highlight.
func (s *Service) ToggleRevision(ctx context.Context, userID, highlightID string, save bool) (Highlight, error) {
	return s.repo.ToggleRevision(ctx, highlightID, userID, save)
}

// ListMine returns the caller's highlights, optionally filtered to revision-saved only.
func (s *Service) ListMine(ctx context.Context, userID string, savedOnly bool) ([]Highlight, error) {
	return s.repo.ListByUser(ctx, userID, savedOnly)
}

// OrphanBySource is a package-level function for other domains to call when
// deleting content that may have associated highlights. Safe to call with a
// pool directly — no Handler/Service/Repo instantiation needed.
// Call pattern:  highlights.OrphanBySource(ctx, pool, "wiki_page", page.ID)
func OrphanBySource(ctx context.Context, pool *pgxpool.Pool, sourceType, sourceID string) error {
	_, err := pool.Exec(ctx,
		`UPDATE highlights
		 SET source_orphaned = TRUE, updated_at = now()
		 WHERE source_type = $1 AND source_id = $2 AND source_orphaned = FALSE`,
		sourceType, sourceID)
	if err != nil {
		return fmt.Errorf("highlights: orphan by source: %w", err)
	}
	return nil
}

// TopExplanations returns the most-served cached explanations for analytics.
func (s *Service) TopExplanations(ctx context.Context, limit int) ([]AnalyticsEntry, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	return s.repo.TopExplanations(ctx, limit)
}

// ─── helpers ─────────────────────────────────────────────────────────────────

// computeHash produces a stable cache key from the normalized text and source type.
// Including source_type means "index" in a lesson and "index" in a wiki page
// get context-appropriate explanations instead of sharing a single generic one.
func computeHash(text, sourceType string) string {
	normalized := strings.ToLower(strings.TrimSpace(text))
	h := sha256.Sum256([]byte(normalized + "|" + sourceType))
	return fmt.Sprintf("%x", h)
}

func validateRequest(sourceType SourceType, text string) error {
	if !validSourceType(sourceType) {
		return ErrInvalidSource
	}
	trimmed := strings.TrimSpace(text)
	if len(trimmed) < 3 {
		return ErrTextTooShort
	}
	if len(trimmed) > 2000 {
		return ErrTextTooLong
	}
	return nil
}

func sourceLabel(s SourceType) string {
	switch s {
	case SourceTypeWikiPage:
		return "wiki article"
	case SourceTypeLesson:
		return "course lesson"
	case SourceTypeProblem:
		return "coding problem description"
	default:
		return "learning resource"
	}
}
