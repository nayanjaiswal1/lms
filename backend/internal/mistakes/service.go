package mistakes

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/srs"
)

// handlerLLM matches handlers.HandlerLLM ("llm.task") — a literal here rather
// than importing internal/jobs/handlers, matching how internal/revisionplan
// enqueues jobs by handler name without importing the handlers package (see
// revisionplan/service.go).
const handlerLLM = "llm.task"

// Service is the one place mistake-logging spans two packages: writing the
// event, and auto-creating the SRS revision card for it. Every other
// operation (list, summary, resolve, delete) is a single repo call and goes
// straight through the handler/MCP tool with no service wrapper.
type Service struct {
	repo         *Repo
	pool         *pgxpool.Pool
	jobsRegistry *jobs.Registry
}

func NewService(repo *Repo, pool *pgxpool.Pool, jobsRegistry *jobs.Registry) *Service {
	return &Service{repo: repo, pool: pool, jobsRegistry: jobsRegistry}
}

// LogMistake records the mistake and creates its spaced-revision card.
// MaybeCreateCard's own dedup only skips on a matching QuestionID, which is
// always nil here, so a card is created for every mistake — each mistake
// gets its own revision card, unlike assessment questions which share one
// card across retries. The card is created immediately with a naive
// templated front/back so it's servable right away; an async
// mistake_card_generate job (internal/jobs/handlers/llm.go) then rewrites it
// into an AI-authored card, keyed off this mistake entry's own ID rather than
// the card ID so the enqueue never needs the card row back from MaybeCreateCard.
func (s *Service) LogMistake(ctx context.Context, userID string, req LogRequest) (Entry, error) {
	if !ValidCategories[req.Category] {
		return Entry{}, fmt.Errorf("mistakes: invalid category %q", req.Category)
	}

	entry, err := s.repo.Create(ctx, userID, req)
	if err != nil {
		return Entry{}, err
	}

	err = srs.MaybeCreateCard(ctx, s.pool, userID, srs.CreateCardRequest{
		MistakeEntryID: &entry.ID,
		Front:          entry.OriginalText + " — what's the correction?",
		Back:           entry.CorrectedText,
		SourceType:     "mistake",
	})
	if err != nil {
		return Entry{}, fmt.Errorf("mistakes: create revision card: %w", err)
	}

	if _, err := jobs.Enqueue(ctx, s.pool, s.jobsRegistry, jobs.EnqueueParams{
		Handler:   handlerLLM,
		Priority:  jobs.PriorityNormal,
		CreatedBy: &userID,
		Payload: map[string]any{
			"task":      "mistake_card_generate",
			"entity_id": entry.ID,
			"params":    map[string]any{},
		},
	}); err != nil {
		return Entry{}, fmt.Errorf("mistakes: enqueue card generation: %w", err)
	}

	return entry, nil
}
