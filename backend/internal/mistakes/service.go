package mistakes

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/srs"
)

// Service is the one place mistake-logging spans two packages: writing the
// event, and auto-creating the SRS revision card for it. Every other
// operation (list, summary, resolve, delete) is a single repo call and goes
// straight through the handler/MCP tool with no service wrapper.
type Service struct {
	repo *Repo
	pool *pgxpool.Pool
}

func NewService(repo *Repo, pool *pgxpool.Pool) *Service {
	return &Service{repo: repo, pool: pool}
}

// LogMistake records the mistake and creates its spaced-revision card.
// MaybeCreateCard's own dedup only skips on a matching QuestionID, which is
// always nil here, so a card is created for every mistake — each mistake
// gets its own revision card, unlike assessment questions which share one
// card across retries.
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

	return entry, nil
}
