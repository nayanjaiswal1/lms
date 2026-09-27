package workspace

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"

	"github.com/mindforge/backend/internal/db"
	"github.com/mindforge/backend/internal/notifications"
)

type assigneeKey struct{ userID, role string }

// SetAssignees replaces an item's full assignee set (contract-phase2.md
// "Assignees"): manager+/the item's track lead may set anything; a plain
// member may only add themselves as owner (when unassigned, in-track,
// onboarding complete) or remove themselves.
func (s *Service) SetAssignees(ctx context.Context, pc *ProjectCtx, itemID string, req SetAssigneesRequest) ([]Assignee, error) {
	if err := ValidateAssigneeRoles(req.Assignees); err != nil {
		return nil, err
	}

	var result []Assignee
	err := s.repo.InTx(ctx, func(tx pgx.Tx) error {
		item, err := s.repo.LockWorkItem(ctx, tx, pc.ProjectID, itemID)
		if err != nil {
			return err
		}
		current, err := s.repo.ListAssigneesByItem(ctx, tx, item.ID)
		if err != nil {
			return err
		}

		privileged := RoleAtLeast(pc.Role, RoleManager)
		if !privileged && item.TrackID != nil {
			lead, err := s.repo.IsTrackLead(ctx, tx, pc.ProjectID, *item.TrackID, pc.UserID)
			if err != nil {
				return err
			}
			privileged = lead
		}

		currentSet := map[assigneeKey]bool{}
		hadOwner := false
		for _, a := range current {
			currentSet[assigneeKey{a.UserID, a.Role}] = true
			if a.Role == AssigneeOwner {
				hadOwner = true
			}
		}
		desiredSet := map[assigneeKey]bool{}
		for _, a := range req.Assignees {
			desiredSet[assigneeKey{a.UserID, a.Role}] = true
		}

		if !privileged {
			for k := range desiredSet {
				if currentSet[k] {
					continue
				}
				if k.userID != pc.UserID || k.role != AssigneeOwner {
					return ErrForbidden
				}
				if hadOwner {
					return ErrForbidden
				}
				if item.TrackID != nil {
					approved, err := s.repo.IsApprovedTrackMember(ctx, tx, *item.TrackID, pc.UserID)
					if err != nil {
						return err
					}
					if !approved {
						return ErrForbidden
					}
				}
				canSelf, err := s.CanSelfAssign(ctx, tx, pc.ProjectID, pc.UserID)
				if err != nil {
					return err
				}
				if !canSelf {
					return ErrOnboardingIncomplete
				}
			}
			for k := range currentSet {
				if desiredSet[k] {
					continue
				}
				if k.userID != pc.UserID {
					return ErrForbidden
				}
			}
		}

		if item.Type == ItemTypeTask && item.TrackID == nil && len(req.Assignees) > 0 {
			return fmt.Errorf(`%w: set the feature's track first`, ErrPreconditionFail)
		}
		if item.TrackID != nil && !privileged {
			track, err := s.repo.GetTrack(ctx, tx, pc.ProjectID, *item.TrackID)
			if err != nil {
				return err
			}
			if track.LeadUserID == nil {
				for k := range desiredSet {
					if !currentSet[k] {
						return ErrTrackLeaderless
					}
				}
			}
		}

		for _, a := range req.Assignees {
			member, err := s.repo.GetMember(ctx, tx, pc.ProjectID, a.UserID)
			if err != nil {
				return err
			}
			if member.Status != MemberActive {
				return fmt.Errorf("%w: assignee must be an active project member", ErrInvalidInput)
			}
			if member.Role != RoleOwner && member.Role != RoleManager && item.TrackID != nil {
				approved, err := s.repo.IsApprovedTrackMember(ctx, tx, *item.TrackID, a.UserID)
				if err != nil {
					return err
				}
				if !approved {
					return fmt.Errorf("%w: %s must be an approved member of this item's track", ErrInvalidInput, member.Name)
				}
			}
		}

		actor := pc.UserID
		for k := range desiredSet {
			if currentSet[k] {
				continue
			}
			if err := s.repo.InsertAssignee(ctx, tx, item.ID, k.userID, k.role, actor); err != nil {
				if db.IsUniqueViolation(err) {
					return ErrConflict
				}
				return fmt.Errorf("workspace: set assignees: insert: %w", err)
			}
			if err := s.repo.InsertItemEvent(ctx, tx, eventInsert{
				ProjectID: pc.ProjectID, ItemID: item.ID, ActorID: &actor, Source: SourceUser, Kind: EventAssign,
				Field: strPtr(k.userID), ToValue: strPtr(k.role),
			}); err != nil {
				return err
			}
		}
		for k := range currentSet {
			if desiredSet[k] {
				continue
			}
			if err := s.repo.DeleteAssignee(ctx, tx, item.ID, k.userID, k.role); err != nil {
				return err
			}
			if err := s.repo.InsertItemEvent(ctx, tx, eventInsert{
				ProjectID: pc.ProjectID, ItemID: item.ID, ActorID: &actor, Source: SourceUser, Kind: EventUnassign,
				Field: strPtr(k.userID), FromValue: strPtr(k.role),
			}); err != nil {
				return err
			}
		}

		// contract-phase3.md "Reviewer removed": the last reviewer disappearing
		// while the spec is in_review needs a human to notice and re-assign one.
		if item.Type == ItemTypeFeature && item.DocStatus != nil && *item.DocStatus == DocInReview {
			hadReviewer, hasReviewer := false, false
			for k := range currentSet {
				if k.role == AssigneeReviewer {
					hadReviewer = true
				}
			}
			for k := range desiredSet {
				if k.role == AssigneeReviewer {
					hasReviewer = true
				}
			}
			if hadReviewer && !hasReviewer {
				managers, err := s.repo.ListManagerUserIDs(ctx, tx, pc.ProjectID)
				if err != nil {
					return err
				}
				if len(managers) > 0 {
					body := fmt.Sprintf("%s lost its last reviewer while its spec is in review.", item.Key)
					if err := s.notif.NotifyMany(ctx, tx, notifications.New{
						OrgID: pc.OrgID, Type: "workspace_doc_reviewerless", Title: "Spec has no reviewer", Body: &body,
						EntityType: strPtr("work_item"), EntityID: &item.ID,
						DedupeKey: fmt.Sprintf("workspace_doc_reviewerless:%s:%d", item.ID, item.Version),
					}, managers); err != nil {
						return fmt.Errorf("workspace: set assignees: notify managers: %w", err)
					}
				}
			}
		}

		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_item.assignees_set", "work_item", item.ID, nil)
		result, err = s.repo.ListAssigneesByItem(ctx, tx, item.ID)
		return err
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}
