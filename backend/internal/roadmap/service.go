package roadmap

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/jobs"
)

// handlerLLM matches handlers.HandlerLLM ("llm.task") — a literal here rather
// than importing internal/jobs/handlers, matching how other domain packages
// (e.g. assessment) enqueue jobs by handler name without importing the
// handlers package.
const handlerLLM = "llm.task"

var (
	ErrInvalidGoal = errors.New("roadmap: goal_description is required")
)

type Service struct {
	repo         *Repo
	pool         *pgxpool.Pool
	jobsRegistry *jobs.Registry
}

func NewService(repo *Repo, pool *pgxpool.Pool, jobsRegistry *jobs.Registry) *Service {
	return &Service{repo: repo, pool: pool, jobsRegistry: jobsRegistry}
}

func (s *Service) enqueueGeneration(ctx context.Context, roadmapID, userID string, orgID *string) error {
	payload := map[string]any{
		"task":      "roadmap_generate",
		"entity_id": roadmapID,
		"params":    map[string]any{},
	}
	_, err := jobs.Enqueue(ctx, s.pool, s.jobsRegistry, jobs.EnqueueParams{
		Handler:   handlerLLM,
		Priority:  jobs.PriorityNormal,
		Payload:   payload,
		OrgID:     orgID,
		CreatedBy: &userID,
	})
	if err != nil {
		return fmt.Errorf("roadmap: enqueue generation: %w", err)
	}
	return nil
}

// Create validates the goal, inserts a roadmap shell, and enqueues async
// generation. The caller (handler) is responsible for the daily creation cap.
func (s *Service) Create(ctx context.Context, userID string, orgID *string, req CreateRequest) (Roadmap, error) {
	goal := strings.TrimSpace(req.GoalDescription)
	if goal == "" {
		return Roadmap{}, ErrInvalidGoal
	}
	if len(goal) > 2000 {
		goal = goal[:2000]
	}

	title := strings.TrimSpace(req.Title)
	if title == "" {
		title = defaultTitle(req.TargetRole, goal)
	}
	if len(title) > 200 {
		title = title[:200]
	}

	rm := Roadmap{
		UserID:          userID,
		OrgID:           orgID,
		Title:           title,
		GoalDescription: goal,
		FocusAreas:      req.FocusAreas,
	}
	if tr := strings.TrimSpace(req.TargetRole); tr != "" {
		rm.TargetRole = &tr
	}
	if sl := strings.TrimSpace(req.SkillLevel); sl != "" {
		rm.SkillLevel = &sl
	}
	if req.TimeframeWeeks > 0 {
		weeks := req.TimeframeWeeks
		if weeks > 104 {
			weeks = 104
		}
		rm.TimeframeWeeks = &weeks
	}

	created, err := s.repo.CreateShell(ctx, rm)
	if err != nil {
		return Roadmap{}, err
	}

	if err := s.enqueueGeneration(ctx, created.ID, userID, orgID); err != nil {
		return Roadmap{}, err
	}
	return created, nil
}

func defaultTitle(targetRole, goal string) string {
	if strings.TrimSpace(targetRole) != "" {
		return "Roadmap: " + strings.TrimSpace(targetRole)
	}
	if len(goal) > 60 {
		return "Roadmap: " + strings.TrimSpace(goal[:60]) + "…"
	}
	return "Roadmap: " + goal
}

// Get fetches a roadmap's full tree. If userID is non-empty and owns it,
// returns the full editable view. Otherwise (anonymous caller, or an
// authenticated caller who isn't the owner) falls back to the public view —
// is_public + active/completed, no ownership check — so GET /api/roadmaps/:id
// serves both an owner's roadmap and anyone's shared one from the same URL,
// no separate "public" path needed.
func (s *Service) Get(ctx context.Context, id, userID string) (Roadmap, error) {
	if userID != "" {
		rm, err := s.repo.GetForUser(ctx, id, userID)
		if err == nil {
			return rm, nil
		}
		if !errors.Is(err, ErrNotFound) {
			return Roadmap{}, err
		}
	}
	return s.repo.GetPublicWithTree(ctx, id)
}

// List returns the user's roadmaps without the nested tree.
func (s *Service) List(ctx context.Context, userID string) ([]Roadmap, error) {
	return s.repo.ListForUser(ctx, userID)
}

// Regenerate re-runs generation into the same roadmap, replacing its tree.
// Rejects with ErrAlreadyGenerating if a generation is already in flight.
func (s *Service) Regenerate(ctx context.Context, id, userID string, orgID *string) error {
	if err := s.repo.SetGenerating(ctx, id, userID); err != nil {
		return err
	}
	return s.enqueueGeneration(ctx, id, userID, orgID)
}

// UpdateModuleProgress marks a module complete/incomplete.
func (s *Service) UpdateModuleProgress(ctx context.Context, roadmapID, moduleID, userID string, completed bool) error {
	return s.repo.UpdateModuleProgress(ctx, roadmapID, moduleID, userID, completed)
}

// UpdateModule renames/redescribes a module (DEFINED-mode light edit).
func (s *Service) UpdateModule(ctx context.Context, roadmapID, moduleID, userID string, title, description *string) error {
	if title != nil {
		t := strings.TrimSpace(*title)
		if t == "" {
			return fmt.Errorf("roadmap: title cannot be empty")
		}
		if len(t) > 200 {
			t = t[:200]
		}
		title = &t
	}
	return s.repo.UpdateModule(ctx, roadmapID, moduleID, userID, title, description)
}

// DeleteModule removes a single module (DEFINED-mode light edit).
func (s *Service) DeleteModule(ctx context.Context, roadmapID, moduleID, userID string) error {
	return s.repo.DeleteModule(ctx, roadmapID, moduleID, userID)
}

// UpdateRoadmap renames, changes status (archive/reactivate), and/or flips
// is_public — the owner's "share this roadmap" toggle.
func (s *Service) UpdateRoadmap(ctx context.Context, id, userID string, title, status *string, isPublic *bool) error {
	if title != nil {
		t := strings.TrimSpace(*title)
		if t == "" {
			return fmt.Errorf("roadmap: title cannot be empty")
		}
		if len(t) > 200 {
			t = t[:200]
		}
		title = &t
	}
	if status != nil {
		switch *status {
		case StatusActive, StatusArchived, StatusCompleted:
		default:
			return fmt.Errorf("roadmap: invalid status %q", *status)
		}
	}
	return s.repo.UpdateRoadmap(ctx, id, userID, title, status, isPublic)
}

// Delete soft-deletes a roadmap.
func (s *Service) Delete(ctx context.Context, id, userID string) error {
	return s.repo.SoftDelete(ctx, id, userID)
}

// ListPublic returns the browse gallery of roadmaps their owners have shared.
func (s *Service) ListPublic(ctx context.Context) ([]Roadmap, error) {
	return s.repo.ListPublic(ctx)
}

// Fork copies a public roadmap's tree into a brand-new roadmap owned by
// userID, active immediately (no AI call — the content already exists).
// Resource links are re-matched against the caller's own org scope rather
// than copied verbatim (see RematchForOrg) so a fork never points at content
// the new owner's org can't see.
func (s *Service) Fork(ctx context.Context, sourceID, userID string, orgID *string) (Roadmap, error) {
	src, err := s.repo.GetPublicWithTree(ctx, sourceID)
	if err != nil {
		return Roadmap{}, err
	}

	phases, err := RematchForOrg(ctx, s.pool, orgID, src.Phases)
	if err != nil {
		return Roadmap{}, err
	}

	created, err := s.repo.CreateFromFork(ctx, Roadmap{
		UserID:          userID,
		OrgID:           orgID,
		Title:           src.Title,
		GoalDescription: src.GoalDescription,
		TargetRole:      src.TargetRole,
		SkillLevel:      src.SkillLevel,
		TimeframeWeeks:  src.TimeframeWeeks,
		FocusAreas:      src.FocusAreas,
	})
	if err != nil {
		return Roadmap{}, err
	}

	if err := s.repo.ReplaceGeneratedTree(ctx, created.ID, phases); err != nil {
		return Roadmap{}, err
	}
	created.Phases = phases
	return created, nil
}
