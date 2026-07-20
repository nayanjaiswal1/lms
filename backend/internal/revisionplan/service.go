package revisionplan

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/jobs"
)

// handlerLLM matches handlers.HandlerLLM ("llm.task") — a literal here rather
// than importing internal/jobs/handlers, matching how internal/roadmap
// enqueues jobs by handler name without importing the handlers package (see
// roadmap/service.go).
const handlerLLM = "llm.task"

var ErrCourseNotComplete = errors.New("revisionplan: course not yet completed")

type Service struct {
	repo         *Repo
	pool         *pgxpool.Pool
	jobsRegistry *jobs.Registry
}

func NewService(repo *Repo, pool *pgxpool.Pool, jobsRegistry *jobs.Registry) *Service {
	return &Service{repo: repo, pool: pool, jobsRegistry: jobsRegistry}
}

// Generate creates (or resets) the revision plan shell for userID's courseID
// and enqueues async AI generation. Rejects with ErrCourseNotComplete unless
// every module in the course is already marked completed for this user — a
// revision plan only makes sense once there's a full course of performance
// signal to reason about, and this check is server-side so a client can't
// request one early by racing the completion check.
func (s *Service) Generate(ctx context.Context, userID, courseID, orgID string) (RevisionPlan, error) {
	complete, err := s.repo.IsCourseComplete(ctx, userID, courseID)
	if err != nil {
		return RevisionPlan{}, err
	}
	if !complete {
		return RevisionPlan{}, ErrCourseNotComplete
	}

	plan, err := s.repo.CreateOrResetShell(ctx, userID, courseID, orgID)
	if err != nil {
		return RevisionPlan{}, err
	}

	payload := map[string]any{
		"task":      "revision_plan_generate",
		"entity_id": plan.ID,
		"params":    map[string]any{},
	}
	if _, err := jobs.Enqueue(ctx, s.pool, s.jobsRegistry, jobs.EnqueueParams{
		Handler:   handlerLLM,
		Priority:  jobs.PriorityNormal,
		Payload:   payload,
		OrgID:     &orgID,
		CreatedBy: &userID,
	}); err != nil {
		return RevisionPlan{}, fmt.Errorf("revisionplan: enqueue generation: %w", err)
	}
	return plan, nil
}

// Get returns userID's revision plan for courseID, if one has been requested.
func (s *Service) Get(ctx context.Context, userID, courseID string) (RevisionPlan, error) {
	return s.repo.GetForUser(ctx, userID, courseID)
}
