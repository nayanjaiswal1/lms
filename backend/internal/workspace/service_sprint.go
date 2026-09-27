package workspace

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/mindforge/backend/internal/db"
)

// service_sprint.go — Phase 5 (contract-phase5.md 5a): sprint CRUD, the
// planned→active→completed lifecycle, and item sprint assignment.

// ListSprints is GET …/sprints (viewer, no status gate).
func (s *Service) ListSprints(ctx context.Context, pc *ProjectCtx) ([]Sprint, error) {
	return s.repo.ListSprints(ctx, s.pool, pc.ProjectID)
}

// CreateSprint is POST …/sprints (manager+, StatusesWork; sprints_enabled).
func (s *Service) CreateSprint(ctx context.Context, pc *ProjectCtx, req CreateSprintRequest) (*Sprint, error) {
	project, err := s.repo.GetProject(ctx, s.pool, pc.OrgID, pc.ProjectID)
	if err != nil {
		return nil, err
	}
	if !project.SprintsEnabled {
		return nil, ErrSprintsDisabled
	}

	name := strings.TrimSpace(req.Name)
	fields := map[string]string{}
	if len(name) < 1 || len(name) > SprintNameMaxLen {
		fields["name"] = fmt.Sprintf("Name must be 1-%d characters.", SprintNameMaxLen)
	}
	startsOn, startErr := time.Parse("2006-01-02", req.StartsOn)
	if startErr != nil {
		fields["starts_on"] = "Invalid date."
	}
	endsOn, endErr := time.Parse("2006-01-02", req.EndsOn)
	if endErr != nil {
		fields["ends_on"] = "Invalid date."
	}
	if startErr == nil && endErr == nil {
		if !endsOn.After(startsOn) {
			fields["ends_on"] = "End date must be after the start date."
		} else if endsOn.Sub(startsOn) > SprintMaxDays*24*time.Hour {
			fields["ends_on"] = fmt.Sprintf("A sprint can be at most %d days.", SprintMaxDays)
		}
	}
	if len(fields) > 0 {
		return nil, &FieldError{Fields: fields}
	}

	var sprint *Sprint
	err = s.repo.InTx(ctx, func(tx pgx.Tx) error {
		sp, err := s.repo.InsertSprint(ctx, tx, pc.ProjectID, name, req.StartsOn, req.EndsOn, pc.UserID)
		if err != nil {
			if db.IsExclusionViolation(err) {
				return ErrSprintOverlap
			}
			return fmt.Errorf("workspace: create sprint: %w", err)
		}
		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_sprint.created", "sprint", sp.ID, map[string]string{"name": name})
		sprint = sp
		return nil
	})
	if err != nil {
		return nil, err
	}
	return sprint, nil
}

// StartSprint is POST …/sprints/{sprintID}/start (manager+, StatusesWork):
// planned→active, snapshotting commitments. Only one sprint may be active at
// once — the uq_sprints_one_active index turns a second attempt into
// ErrConflict.
func (s *Service) StartSprint(ctx context.Context, pc *ProjectCtx, sprintID string) (*Sprint, error) {
	err := s.repo.InTx(ctx, func(tx pgx.Tx) error {
		current, err := s.repo.LockSprint(ctx, tx, pc.ProjectID, sprintID)
		if err != nil {
			return err
		}
		if !SprintStatusMachine.Allowed(current.Status, SprintActive) {
			return ErrIllegalTransition
		}
		if _, err := s.repo.UpdateSprintStatus(ctx, tx, pc.ProjectID, sprintID, SprintActive); err != nil {
			if db.IsUniqueViolation(err) {
				return ErrConflict
			}
			return fmt.Errorf("workspace: start sprint: %w", err)
		}
		if err := s.repo.SnapshotSprintCommitments(ctx, tx, sprintID); err != nil {
			return err
		}
		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_sprint.started", "sprint", sprintID, nil)
		return nil
	})
	if err != nil {
		return nil, err
	}
	return s.repo.GetSprint(ctx, s.pool, pc.ProjectID, sprintID)
}

// CloseSprint is POST …/sprints/{sprintID}/close (manager+, StatusesWork):
// active→completed, requiring an explicit carry_over/backlog choice for any
// item still open (ErrUnfinishedChoice) — never a silent drop (design §11).
func (s *Service) CloseSprint(ctx context.Context, pc *ProjectCtx, sprintID string, req CloseSprintRequest) (*Sprint, error) {
	err := s.repo.InTx(ctx, func(tx pgx.Tx) error {
		current, err := s.repo.LockSprint(ctx, tx, pc.ProjectID, sprintID)
		if err != nil {
			return err
		}
		if !SprintStatusMachine.Allowed(current.Status, SprintCompleted) {
			return ErrIllegalTransition
		}

		unfinished, err := s.repo.ListUnfinishedSprintItems(ctx, tx, pc.ProjectID, sprintID)
		if err != nil {
			return err
		}
		if len(unfinished) > 0 {
			var nextSprintID *string
			switch req.Unfinished {
			case "carry_over":
				if req.NextSprintID == nil || strings.TrimSpace(*req.NextSprintID) == "" {
					return fmt.Errorf("%w: next_sprint_id is required to carry unfinished items over", ErrInvalidInput)
				}
				next, err := s.repo.GetSprint(ctx, tx, pc.ProjectID, *req.NextSprintID)
				if err != nil {
					return err
				}
				if next.Status != SprintPlanned {
					return fmt.Errorf("%w: the next sprint must still be planned", ErrInvalidInput)
				}
				nextSprintID = req.NextSprintID
			case "backlog":
				nextSprintID = nil
			default:
				return ErrUnfinishedChoice
			}
			actor := pc.UserID
			for _, it := range unfinished {
				if _, err := s.repo.SetItemSprintSystem(ctx, tx, pc.ProjectID, it.ID, nextSprintID); err != nil {
					return err
				}
				if err := s.repo.InsertItemEvent(ctx, tx, eventInsert{
					ProjectID: pc.ProjectID, ItemID: it.ID, ActorID: &actor, Source: SourceUser, Kind: EventSprint,
					FromValue: strPtr(sprintID), ToValue: nextSprintID,
				}); err != nil {
					return err
				}
			}
		}

		if _, err := s.repo.UpdateSprintStatus(ctx, tx, pc.ProjectID, sprintID, SprintCompleted); err != nil {
			return fmt.Errorf("workspace: close sprint: %w", err)
		}
		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_sprint.closed", "sprint", sprintID,
			map[string]any{"unfinished": len(unfinished), "choice": req.Unfinished})
		return nil
	})
	if err != nil {
		return nil, err
	}
	return s.repo.GetSprint(ctx, s.pool, pc.ProjectID, sprintID)
}

// SetItemSprint is PUT …/items/{itemID}/sprint (member; the same editor rule
// UpdateWorkItem uses — creator, any assignee, manager+, or the item's track
// lead). Moving an item into/out of an already-active sprint after it
// started is scope churn, surfaced on the dashboard rather than blocked here.
func (s *Service) SetItemSprint(ctx context.Context, pc *ProjectCtx, itemID string, req SetItemSprintRequest) (*WorkItem, error) {
	current, err := s.repo.GetWorkItemByID(ctx, s.pool, pc.ProjectID, itemID)
	if err != nil {
		return nil, err
	}
	current.Assignees, err = s.repo.ListAssigneesByItem(ctx, s.pool, current.ID)
	if err != nil {
		return nil, err
	}
	canEdit, err := s.canEditItem(ctx, s.pool, pc, current)
	if err != nil {
		return nil, err
	}
	if !canEdit {
		return nil, ErrForbidden
	}

	project, err := s.repo.GetProject(ctx, s.pool, pc.OrgID, pc.ProjectID)
	if err != nil {
		return nil, err
	}
	if !project.SprintsEnabled {
		return nil, ErrSprintsDisabled
	}
	if req.SprintID != nil {
		if _, err := s.repo.GetSprint(ctx, s.pool, pc.ProjectID, *req.SprintID); err != nil {
			return nil, err
		}
	}

	var updated *WorkItem
	err = s.repo.InTx(ctx, func(tx pgx.Tx) error {
		u, err := s.repo.SetItemSprint(ctx, tx, pc.ProjectID, itemID, req.Version, req.SprintID)
		if err != nil {
			if err == ErrNotFound {
				fresh, ferr := s.repo.GetWorkItemByID(ctx, tx, pc.ProjectID, itemID)
				if ferr != nil {
					return ferr
				}
				return &ConflictError{Current: fresh}
			}
			return err
		}
		actor := pc.UserID
		if err := s.repo.InsertItemEvent(ctx, tx, eventInsert{
			ProjectID: pc.ProjectID, ItemID: itemID, ActorID: &actor, Source: SourceUser, Kind: EventSprint,
			FromValue: current.SprintID, ToValue: req.SprintID,
		}); err != nil {
			return err
		}
		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_item.sprint_set", "work_item", itemID, nil)
		updated = u
		return nil
	})
	if err != nil {
		return nil, err
	}
	return updated, nil
}
