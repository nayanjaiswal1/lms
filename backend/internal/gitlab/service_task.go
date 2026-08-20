package gitlab

import (
	"context"
	"time"
)

// ─── Batch 7: day-to-day task board ────────────────────────────────────────
// Every call is any team member (membership verified via Repo.GetMyProject,
// same guard service_design.go uses) — this is an ungraded, self-managed
// board, not a staff-only surface like checkpoints/grading.

// validTaskStatuses is the set CreateTask/UpdateTask accept.
var validTaskStatuses = map[string]bool{
	TaskStatusTodo: true, TaskStatusInProgress: true, TaskStatusReview: true, TaskStatusDone: true,
}

// CreateTask adds a task to a team's board. checkpointID is optional context
// (which SDLC gate this supports) — when non-nil, verified to belong to the
// same team's assignment, same guard SubmitDesignProposal uses.
func (s *Service) CreateTask(ctx context.Context, orgID, userID, teamID, title string, description, checkpointID *string, dueAt *time.Time) (*ProjectTask, error) {
	team, err := s.repo.GetMyProject(ctx, orgID, userID, teamID)
	if err != nil {
		return nil, err
	}
	if checkpointID != nil {
		checkpoint, err := s.repo.GetCheckpoint(ctx, orgID, *checkpointID)
		if err != nil {
			return nil, err
		}
		if checkpoint.AssignmentID != team.AssignmentID {
			return nil, ErrNotFound
		}
	}
	return s.repo.CreateTask(ctx, ProjectTask{
		OrgID: orgID, TeamID: teamID, CheckpointID: checkpointID, Title: title, Description: description, DueAt: dueAt, CreatedBy: userID,
	})
}

// ListTasksForTeam returns a team's board — same membership guard.
func (s *Service) ListTasksForTeam(ctx context.Context, orgID, userID, teamID string) ([]ProjectTask, error) {
	if _, err := s.repo.GetMyProject(ctx, orgID, userID, teamID); err != nil {
		return nil, err
	}
	return s.repo.ListTasksForTeam(ctx, teamID)
}

// getOwnTask fetches taskID and verifies the caller belongs to its team —
// the shared guard UpdateTask/SetTaskAssignee/DeleteTask all use.
func (s *Service) getOwnTask(ctx context.Context, orgID, userID, taskID string) (*ProjectTask, error) {
	task, err := s.repo.GetTask(ctx, orgID, taskID)
	if err != nil {
		return nil, err
	}
	if _, err := s.repo.GetMyProject(ctx, orgID, userID, task.TeamID); err != nil {
		return nil, err
	}
	return task, nil
}

// UpdateTask applies a partial patch, after verifying the caller belongs to
// the task's team.
func (s *Service) UpdateTask(ctx context.Context, orgID, userID, taskID string, p TaskPatch) (*ProjectTask, error) {
	if _, err := s.getOwnTask(ctx, orgID, userID, taskID); err != nil {
		return nil, err
	}
	return s.repo.UpdateTask(ctx, orgID, taskID, p)
}

// SetTaskAssignee reassigns (or clears, when assigneeUserID is nil) a task —
// same membership guard.
func (s *Service) SetTaskAssignee(ctx context.Context, orgID, userID, taskID string, assigneeUserID *string) (*ProjectTask, error) {
	if _, err := s.getOwnTask(ctx, orgID, userID, taskID); err != nil {
		return nil, err
	}
	return s.repo.SetTaskAssignee(ctx, orgID, taskID, assigneeUserID)
}

// DeleteTask removes a task — same membership guard.
func (s *Service) DeleteTask(ctx context.Context, orgID, userID, taskID string) error {
	if _, err := s.getOwnTask(ctx, orgID, userID, taskID); err != nil {
		return err
	}
	return s.repo.DeleteTask(ctx, orgID, taskID)
}
