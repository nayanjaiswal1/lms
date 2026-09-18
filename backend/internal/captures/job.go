package captures

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/journal"
	"github.com/mindforge/backend/internal/storage"
)

// JobPayload is the JSON payload for captures.process jobs (see
// internal/jobs/handlers/captures_process.go, the thin jobs.Handler that
// unmarshals this and calls Processor.Process).
type JobPayload struct {
	CaptureID string `json:"capture_id"`
	UserID    string `json:"user_id"`
}

// Processor turns a pending capture into a ready one: extract text (or
// attach the image directly for vision), ask the AI to classify + structure
// it, store the result. Never writes to learning_journal_entries or
// srs_cards itself — that only happens when the user reviews and promotes
// (see Handler.Promote) — a capture landing in the inbox is never silently
// turned into real data.
type Processor struct {
	repo    *Repo
	journal *journal.Repo
	storage storage.StorageClient
	ai      ai.LLMProvider
	cfg     *config.Config
}

// NewProcessor constructs a Processor with all dependencies injected.
func NewProcessor(pool *pgxpool.Pool, storageClient storage.StorageClient, aiProvider ai.LLMProvider, cfg *config.Config) *Processor {
	return &Processor{
		repo:    NewRepo(pool),
		journal: journal.NewRepo(pool),
		storage: storageClient,
		ai:      aiProvider,
		cfg:     cfg,
	}
}

// Process runs the full pipeline for one capture. Idempotent: a retried job
// (or a duplicate enqueue) that lands on an already-processing/ready/failed
// capture is a no-op via MarkProcessing's RowsAffected guard below.
func (pr *Processor) Process(ctx context.Context, captureID, userID string) error {
	cp, err := pr.repo.GetCaptureByID(ctx, captureID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			slog.InfoContext(ctx, "captures.Process: capture not found, skipping", "capture_id", captureID)
			return nil
		}
		return fmt.Errorf("captures.Process: fetch capture %s: %w", captureID, err)
	}
	if cp.UserID != userID {
		return fmt.Errorf("captures.Process: user_id mismatch, refusing to process (capture %s)", captureID)
	}

	claimed, err := pr.repo.MarkProcessing(ctx, captureID)
	if err != nil {
		return fmt.Errorf("captures.Process: mark processing (capture %s): %w", captureID, err)
	}
	if !claimed {
		slog.InfoContext(ctx, "captures.Process: already claimed by another run, skipping", "capture_id", captureID)
		return nil
	}

	extractedText, image, err := pr.extract(ctx, cp)
	if err != nil {
		if markErr := pr.repo.MarkFailed(ctx, captureID, err.Error()); markErr != nil {
			return fmt.Errorf("captures.Process: mark failed (capture %s): %w", captureID, markErr)
		}
		return nil // extraction failure is a terminal, non-retryable outcome for this capture
	}

	if !pr.ai.Available() {
		if markErr := pr.repo.MarkFailed(ctx, captureID, "AI provider not available"); markErr != nil {
			return fmt.Errorf("captures.Process: mark failed (capture %s): %w", captureID, markErr)
		}
		return nil
	}

	categories, err := pr.journal.ListCategories(ctx, userID)
	if err != nil {
		return fmt.Errorf("captures.Process: list categories (capture %s): %w", captureID, err)
	}

	llmCtx, cancel := context.WithTimeout(ctx, pr.cfg.LLMTimeout)
	defer cancel()

	resp, err := pr.ai.Complete(llmCtx, ai.CompletionRequest{
		SystemPrompt: ai.CaptureStructureSystemPrompt,
		UserPrompt:   buildCaptureUserPrompt(extractedText, categories),
		Image:        image,
		MaxTokens:    4096,
		Temperature:  0.3,
		JSONMode:     true,
	})
	if err != nil {
		reason := "AI structuring failed. You can retry from the inbox."
		if markErr := pr.repo.MarkFailed(ctx, captureID, reason); markErr != nil {
			return fmt.Errorf("captures.Process: mark failed (capture %s): %w", captureID, markErr)
		}
		return fmt.Errorf("captures.Process: AI call (capture %s): %w", captureID, err)
	}

	var parsed StructuredSuggestion
	if err := json.Unmarshal([]byte(resp.Content), &parsed); err != nil {
		if markErr := pr.repo.MarkFailed(ctx, captureID, "Could not parse the AI response. You can retry from the inbox."); markErr != nil {
			return fmt.Errorf("captures.Process: mark failed (capture %s): %w", captureID, markErr)
		}
		return fmt.Errorf("captures.Process: parse AI response (capture %s): %w", captureID, err)
	}

	parsed.Kind = strings.TrimSpace(parsed.Kind)
	if parsed.Kind != KindQuestion {
		parsed.Kind = KindNote
	}
	parsed.Category = clampField(parsed.Category, 60)
	parsed.Subcategory = clampField(parsed.Subcategory, 60)
	parsed.Title = clampField(parsed.Title, 200)
	parsed.Content = clampField(parsed.Content, 20000)
	if parsed.Title == "" || parsed.Content == "" {
		if markErr := pr.repo.MarkFailed(ctx, captureID, "AI response missing title/content. You can retry from the inbox."); markErr != nil {
			return fmt.Errorf("captures.Process: mark failed (capture %s): %w", captureID, markErr)
		}
		return fmt.Errorf("captures.Process: AI structure response missing required fields (capture %s)", captureID)
	}
	if parsed.Kind == KindNote && (parsed.Category == "" || parsed.Subcategory == "") {
		parsed.Category = "Captures"
		parsed.Subcategory = "Uncategorized"
	}

	if err := pr.repo.MarkReady(ctx, captureID, extractedText, parsed); err != nil {
		return fmt.Errorf("captures.Process: mark ready (capture %s): %w", captureID, err)
	}

	slog.InfoContext(ctx, "captures.Process: capture structured", "capture_id", captureID, "kind", parsed.Kind, "model", resp.Model)
	return nil
}

// extract turns a capture's raw source into either extracted text (pdf/link)
// or an attached image (image) for the AI call. The returned text is always
// non-empty for pdf/link on success; image returns "" text and a non-nil
// *ai.ImageInput instead.
func (pr *Processor) extract(ctx context.Context, cp Capture) (string, *ai.ImageInput, error) {
	switch cp.Type {
	case TypeImage:
		if cp.StorageKey == nil {
			return "", nil, fmt.Errorf("captures: image capture missing storage key")
		}
		data, err := pr.storage.Download(ctx, *cp.StorageKey)
		if err != nil {
			return "", nil, fmt.Errorf("captures: download image: %w", err)
		}
		mediaType := http.DetectContentType(data)
		if !strings.HasPrefix(mediaType, "image/") {
			return "", nil, fmt.Errorf("captures: stored object is not an image (%s)", mediaType)
		}
		return "", &ai.ImageInput{Base64: base64.StdEncoding.EncodeToString(data), MediaType: mediaType}, nil

	case TypePDF:
		if cp.StorageKey == nil {
			return "", nil, fmt.Errorf("captures: pdf capture missing storage key")
		}
		data, err := pr.storage.Download(ctx, *cp.StorageKey)
		if err != nil {
			return "", nil, fmt.Errorf("captures: download pdf: %w", err)
		}
		text, err := ExtractPDFText(ctx, data)
		if err != nil {
			return "", nil, err
		}
		return text, nil, nil

	case TypeLink:
		if cp.SourceURL == nil {
			return "", nil, fmt.Errorf("captures: link capture missing source url")
		}
		_, text, err := FetchLinkText(ctx, *cp.SourceURL)
		if err != nil {
			return "", nil, err
		}
		return text, nil, nil

	case TypeHTML:
		// Already extracted synchronously at creation (Repo.CreateHTMLCapture)
		// — no fetch, no re-parse needed here.
		if cp.ExtractedText == nil || *cp.ExtractedText == "" {
			return "", nil, fmt.Errorf("captures: html capture missing extracted text")
		}
		return *cp.ExtractedText, nil, nil

	default:
		return "", nil, fmt.Errorf("captures: unknown capture type %q", cp.Type)
	}
}

// buildCaptureUserPrompt mirrors journal.buildStructureUserPrompt: list the
// user's existing category/subcategory pairs so the AI reuses one instead of
// inventing a near-duplicate, then the extracted text (empty when an image
// is attached instead — the prompt only needs one or the other).
func buildCaptureUserPrompt(extractedText string, categories []journal.CategoryNode) string {
	var sb strings.Builder
	if len(categories) > 0 {
		sb.WriteString("Existing category / subcategory pairs:\n")
		for _, c := range categories {
			for _, sc := range c.Subcategories {
				fmt.Fprintf(&sb, "- %s / %s\n", c.Category, sc)
			}
		}
		sb.WriteString("\n")
	}
	if extractedText != "" {
		sb.WriteString("Extracted text:\n")
		sb.WriteString(extractedText)
	} else {
		sb.WriteString("(An image is attached — read it directly.)")
	}
	return sb.String()
}

// clampField mirrors journal.clampField — trims whitespace and caps length
// so a slightly-over-limit AI response degrades to a truncated value instead
// of failing MarkReady's DB length constraints.
func clampField(s string, maxLen int) string {
	s = strings.TrimSpace(s)
	if len(s) > maxLen {
		s = strings.TrimSpace(s[:maxLen])
	}
	return s
}
