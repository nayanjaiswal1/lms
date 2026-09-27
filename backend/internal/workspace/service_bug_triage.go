package workspace

import (
	"context"
	"fmt"
	"log/slog"
	"strings"

	"github.com/jackc/pgx/v5"

	"github.com/mindforge/backend/internal/notifications"
)

// TriageBug is manager+/the bug's track lead deciding a newly-reported bug:
// duplicate, not a bug, or confirmed (contract-phase3.md "TriageBug").
func (s *Service) TriageBug(ctx context.Context, pc *ProjectCtx, itemID string, req TriageBugRequest) (*WorkItem, error) {
	if !contains([]string{TriageDuplicate, TriageNotABug, TriageConfirmed}, req.Decision) {
		return nil, fmt.Errorf("%w: decision must be duplicate, not_a_bug, or confirmed", ErrInvalidInput)
	}
	item, err := s.repo.GetWorkItemByID(ctx, s.pool, pc.ProjectID, itemID)
	if err != nil {
		return nil, err
	}
	if item.Type != ItemTypeBug {
		return nil, fmt.Errorf("%w: triage only applies to bugs", ErrInvalidInput)
	}
	privileged := RoleAtLeast(pc.Role, RoleManager)
	if !privileged && item.TrackID != nil {
		lead, err := s.repo.IsTrackLead(ctx, s.pool, pc.ProjectID, *item.TrackID, pc.UserID)
		if err != nil {
			return nil, err
		}
		privileged = lead
	}
	if !privileged {
		return nil, ErrForbidden
	}

	switch req.Decision {
	case TriageDuplicate:
		if req.DuplicateOfID == nil || *req.DuplicateOfID == "" {
			return nil, fmt.Errorf("%w: duplicate_of_id is required", ErrInvalidInput)
		}
		if _, err := s.CreateLink(ctx, pc, itemID, CreateLinkRequest{ToItemID: *req.DuplicateOfID, Kind: LinkDuplicates}); err != nil {
			return nil, err
		}
		return s.repo.GetWorkItemByID(ctx, s.pool, pc.ProjectID, itemID)

	case TriageNotABug:
		if req.Reason == nil || strings.TrimSpace(*req.Reason) == "" {
			return nil, ErrReasonRequired
		}
		var updated *WorkItem
		err := s.repo.InTx(ctx, func(tx pgx.Tx) error {
			u, err := s.transitionTx(ctx, tx, transitionInput{
				PC: pc, ItemID: itemID, Source: SourceUser, To: ItemWontDo, Reason: req.Reason, SkipRoleCheck: true,
			})
			if err != nil {
				return err
			}
			writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_bug.triaged_not_a_bug", "work_item", itemID, nil)
			updated = u
			return nil
		})
		return updated, err

	default: // TriageConfirmed
		return s.confirmBug(ctx, pc, itemID, req)
	}
}

// confirmBug applies TriageConfirmed's severity (required), parent move
// (optional) and is_regression together, then the optional owner assignment
// (delegated to SetAssignees's own rules, contract-phase3.md), then an
// immediate S1 escalation — each its own commit, matching how CreateLink's
// duplicate path composes with its own best-effort notify.
func (s *Service) confirmBug(ctx context.Context, pc *ProjectCtx, itemID string, req TriageBugRequest) (*WorkItem, error) {
	if req.Severity == nil || !contains(BugSeverities, *req.Severity) {
		return nil, &FieldError{Fields: map[string]string{"severity": "Severity is required and must be one of S1, S2, S3, S4."}}
	}

	var updated *WorkItem
	err := s.repo.InTx(ctx, func(tx pgx.Tx) error {
		item, err := s.repo.LockWorkItem(ctx, tx, pc.ProjectID, itemID)
		if err != nil {
			return err
		}
		isRegression := item.IsRegression
		if req.IsRegression != nil {
			isRegression = *req.IsRegression
		}
		u, err := s.repo.UpdateItemFields(ctx, tx, pc.ProjectID, itemID, item.Version,
			item.Title, item.Description, item.Priority, req.Severity, isRegression, item.EstimateMinutes, item.DueAt, item.TrackID)
		if err != nil {
			return err
		}
		actor := pc.UserID
		fromSeverity, toSeverity := "", *req.Severity
		if item.Severity != nil {
			fromSeverity = *item.Severity
		}
		if err := s.repo.InsertItemEvent(ctx, tx, eventInsert{
			ProjectID: pc.ProjectID, ItemID: itemID, ActorID: &actor, Source: SourceUser, Kind: EventSeverity,
			FromValue: strPtr(fromSeverity), ToValue: &toSeverity,
		}); err != nil {
			return err
		}

		if req.ParentID != nil {
			if err := s.repo.LockItemGraph(ctx, tx, pc.ProjectID); err != nil {
				return err
			}
			var parent *WorkItem
			if *req.ParentID != "" {
				parent, err = s.repo.GetWorkItemByID(ctx, tx, pc.ProjectID, *req.ParentID)
				if err != nil {
					return err
				}
				if parent.ID == itemID {
					return ErrIllegalHierarchy
				}
			}
			parentType := ""
			if parent != nil {
				parentType = parent.Type
			}
			if !ChildAllowed(parentType, ItemTypeBug) {
				return ErrIllegalHierarchy
			}
			epicID, featureID := deriveAncestors(parent)
			var parentIDArg *string
			if parent != nil {
				parentIDArg = &parent.ID
			}
			u, err = s.repo.UpdateItemParent(ctx, tx, pc.ProjectID, itemID, u.Version, parentIDArg, epicID, featureID)
			if err != nil {
				return err
			}
			if err := s.repo.UpdateDescendantAncestors(ctx, tx, pc.ProjectID, itemID, epicID, featureID); err != nil {
				return err
			}
			if err := s.repo.InsertItemEvent(ctx, tx, eventInsert{
				ProjectID: pc.ProjectID, ItemID: itemID, ActorID: &actor, Source: SourceUser, Kind: EventParent,
				FromValue: item.ParentID, ToValue: parentIDArg,
			}); err != nil {
				return err
			}
		}

		writeAudit(ctx, tx, pc.OrgID, &actor, "workspace_bug.triaged_confirmed", "work_item", itemID,
			map[string]string{"severity": *req.Severity})
		updated = u
		return nil
	})
	if err != nil {
		return nil, err
	}

	if req.OwnerUserID != nil {
		current, err := s.repo.ListAssigneesByItem(ctx, s.pool, itemID)
		if err != nil {
			return nil, err
		}
		desired := make([]AssigneeInput, 0, len(current)+1)
		for _, a := range current {
			if a.Role == AssigneeOwner {
				continue
			}
			desired = append(desired, AssigneeInput{UserID: a.UserID, Role: a.Role})
		}
		desired = append(desired, AssigneeInput{UserID: *req.OwnerUserID, Role: AssigneeOwner})
		if _, err := s.SetAssignees(ctx, pc, itemID, SetAssigneesRequest{Assignees: desired}); err != nil {
			return nil, err
		}
		updated, err = s.repo.GetWorkItemByID(ctx, s.pool, pc.ProjectID, itemID)
		if err != nil {
			return nil, err
		}
	}

	if *req.Severity == "S1" {
		s.notifyS1Bug(ctx, pc.OrgID, updated)
	}
	return updated, nil
}

// notifyS1Bug is TriageConfirmed's immediate escalation — best-effort, never
// fails the triage that triggered it (matches notifyDuplicateClosed's shape).
func (s *Service) notifyS1Bug(ctx context.Context, orgID string, item *WorkItem) {
	recipients, err := s.repo.ListManagerUserIDs(ctx, s.pool, item.ProjectID)
	if err != nil {
		slog.ErrorContext(ctx, "workspace: notify s1 bug: list managers", "error", err)
		return
	}
	assignees, err := s.repo.ListAssigneesByItem(ctx, s.pool, item.ID)
	if err != nil {
		slog.ErrorContext(ctx, "workspace: notify s1 bug: list assignees", "error", err)
		return
	}
	seen := map[string]bool{}
	ids := make([]string, 0, len(recipients)+1)
	for _, id := range recipients {
		if !seen[id] {
			seen[id] = true
			ids = append(ids, id)
		}
	}
	for _, a := range assignees {
		if a.Role == AssigneeOwner && !seen[a.UserID] {
			seen[a.UserID] = true
			ids = append(ids, a.UserID)
		}
	}
	if len(ids) == 0 {
		return
	}
	body := fmt.Sprintf("%s (%s) was confirmed as a critical (S1) bug.", item.Key, item.Title)
	err = s.repo.InTx(ctx, func(tx pgx.Tx) error {
		return s.notif.NotifyMany(ctx, tx, notifications.New{
			OrgID: orgID, Type: "workspace_bug_s1", Title: "Critical bug confirmed", Body: &body,
			EntityType: strPtr("work_item"), EntityID: &item.ID, Priority: notifications.PriorityHigh, AlsoEmail: true,
			DedupeKey: "workspace_bug_s1:" + item.ID,
		}, ids)
	})
	if err != nil {
		slog.ErrorContext(ctx, "workspace: notify s1 bug", "error", err)
	}
}
