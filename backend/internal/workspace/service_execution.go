package workspace

import (
	"context"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
)

// transitionInput is transitionTx's own input struct (contract-phase2.md
// leaves its exact shape to this agent). PC carries the already-resolved
// project role/status the public TransitionItem path got from
// RequireProjectRole; internal callers (duplicate-close today, GitLab
// automation in Phase 4) build or reuse a ProjectCtx of their own and set
// SkipRoleCheck so the actor/ownership checks don't apply — SoD checks below
// are never skipped regardless (agent-hard-rules.md).
type transitionInput struct {
	PC              *ProjectCtx
	ItemID          string
	Source          string
	To              string
	Reason          *string
	BlockerItemID   *string
	ExpectedVersion *int
	SkipRoleCheck   bool
}

// TransitionItem is the public entry point for a status change — it always
// checks the caller's optimistic version and never skips role checks.
func (s *Service) TransitionItem(ctx context.Context, pc *ProjectCtx, itemID string, req TransitionRequest) (*WorkItem, error) {
	var updated *WorkItem
	err := s.repo.InTx(ctx, func(tx pgx.Tx) error {
		version := req.Version
		u, err := s.transitionTx(ctx, tx, transitionInput{
			PC: pc, ItemID: itemID, Source: SourceUser, To: req.To, Reason: req.Reason,
			BlockerItemID: req.BlockerItemID, ExpectedVersion: &version,
		})
		if err != nil {
			return err
		}
		updated = u
		return nil
	})
	if err != nil {
		return nil, err
	}
	return updated, nil
}

// transitionTx is the single status-change path (contract-phase2.md):
// TransitionItem, the duplicates-close path (service_links.go), and Phase 4's
// GitLab automation all funnel through here so the machine/role/SoD/WIP/doc
// rules are enforced exactly once.
func (s *Service) transitionTx(ctx context.Context, tx pgx.Tx, t transitionInput) (*WorkItem, error) {
	item, err := s.repo.LockWorkItem(ctx, tx, t.PC.ProjectID, t.ItemID)
	if err != nil {
		return nil, err
	}
	if item.ArchivedAt != nil {
		return nil, ErrNotFound
	}
	if t.ExpectedVersion != nil && item.Version != *t.ExpectedVersion {
		return nil, &ConflictError{Current: item}
	}

	rollup := IsRollupType(item.Type)
	if rollup {
		if t.To != ItemWontDo {
			return nil, ErrIllegalTransition
		}
	} else if !WorkItemStatusMachine.Allowed(item.Status, t.To) {
		return nil, ErrIllegalTransition
	}

	item.Assignees, err = s.repo.ListAssigneesByItem(ctx, tx, item.ID)
	if err != nil {
		return nil, err
	}
	if err := s.checkTransitionGate(ctx, tx, t.PC, item, t.To, t.SkipRoleCheck); err != nil {
		return nil, err
	}

	reasonRequired := t.To == ItemBlocked || t.To == ItemWontDo || t.To == ItemReopened
	if reasonRequired && (t.Reason == nil || strings.TrimSpace(*t.Reason) == "") {
		return nil, ErrReasonRequired
	}
	if t.To == ItemBlocked {
		if t.BlockerItemID == nil || *t.BlockerItemID == "" {
			return nil, fmt.Errorf("%w: blocker_item_id is required", ErrInvalidInput)
		}
		if *t.BlockerItemID == item.ID {
			return nil, fmt.Errorf("%w: an item can't block itself", ErrInvalidInput)
		}
		if _, err := s.repo.GetWorkItemByID(ctx, tx, t.PC.ProjectID, *t.BlockerItemID); err != nil {
			return nil, err
		}
		if err := s.ensureBlocksLink(ctx, tx, t.PC.ProjectID, *t.BlockerItemID, item.ID, t.PC.UserID); err != nil {
			return nil, err
		}
	}

	updated, err := s.repo.UpdateItemStatus(ctx, tx, t.PC.ProjectID, item.ID, t.To, t.Reason)
	if err != nil {
		return nil, fmt.Errorf("workspace: transition item: %w", err)
	}

	actor := t.PC.UserID
	fromStatus := item.Status
	if err := s.repo.InsertItemEvent(ctx, tx, eventInsert{
		ProjectID: t.PC.ProjectID, ItemID: item.ID, ActorID: &actor, Source: t.Source, Kind: EventStatus,
		Field: strPtr("status"), FromValue: &fromStatus, ToValue: &t.To, Reason: t.Reason,
	}); err != nil {
		return nil, err
	}

	if err := s.rollupAncestors(ctx, tx, t.PC.ProjectID, item); err != nil {
		return nil, err
	}

	writeAudit(ctx, tx, t.PC.OrgID, &t.PC.UserID, "workspace_item.transitioned", "work_item", item.ID,
		map[string]string{"from": fromStatus, "to": t.To})
	return updated, nil
}

// checkTransitionGate runs every role/precondition/SoD check for moving item
// to `to`, without writing anything — shared verbatim by transitionTx (the
// real write) and GetWorkItem's legal/locked transition preview
// (contract-phase2.md: "computed by the same rule code the transition
// uses"). skipRoleCheck bypasses only the actor/ownership checks; SoD checks
// (testing, done, reopened-from-testing) always run.
func (s *Service) checkTransitionGate(ctx context.Context, db DBTX, pc *ProjectCtx, item *WorkItem, to string, skipRoleCheck bool) error {
	if IsRollupType(item.Type) {
		if to != ItemWontDo {
			return ErrIllegalTransition
		}
		if !skipRoleCheck && !RoleAtLeast(pc.Role, RoleManager) {
			return ErrForbidden
		}
		return nil
	}

	switch to {
	case ItemInProgress, ItemInReview, ItemTesting, ItemDone:
		if pc.ProjectStatus != ProjectActive {
			return ErrInvalidState
		}
		if pc.BriefStatus != BriefAgreed {
			return ErrBriefNotAgreed
		}
	}

	if to == ItemInProgress && item.Type == ItemTypeTask && item.FeatureID != nil {
		approved, err := s.repo.IsFeatureDocApproved(ctx, db, *item.FeatureID)
		if err != nil {
			return err
		}
		if !approved {
			return ErrDocNotApproved
		}
	}

	assignees := item.Assignees
	hasRole := func(role string) bool {
		for _, a := range assignees {
			if a.Role == role {
				return true
			}
		}
		return false
	}
	hasUserRole := func(userID, role string) bool {
		for _, a := range assignees {
			if a.UserID == userID && a.Role == role {
				return true
			}
		}
		return false
	}
	isAnyAssignee := func(userID string) bool {
		for _, a := range assignees {
			if a.UserID == userID {
				return true
			}
		}
		return false
	}
	userWithRole := func(role string) string {
		for _, a := range assignees {
			if a.Role == role {
				return a.UserID
			}
		}
		return ""
	}
	isOwnerOrDeveloper := hasUserRole(pc.UserID, AssigneeOwner) || hasUserRole(pc.UserID, AssigneeDeveloper)
	isManagerPlus := RoleAtLeast(pc.Role, RoleManager)

	switch to {
	case ItemInProgress:
		if !skipRoleCheck && !isOwnerOrDeveloper && !isManagerPlus {
			return ErrForbidden
		}
		if !hasRole(AssigneeOwner) {
			return fmt.Errorf("%w: assign an owner before starting work", ErrPreconditionFail)
		}
		blockedOpen, err := s.repo.HasOpenIncomingBlock(ctx, db, item.ID)
		if err != nil {
			return err
		}
		if blockedOpen {
			return ErrBlockedByOpen
		}
		s1Exempt := item.Type == ItemTypeBug && item.Severity != nil && *item.Severity == "S1"
		if !s1Exempt {
			ownerID := userWithRole(AssigneeOwner)
			if err := s.repo.LockMemberRow(ctx, db, pc.ProjectID, ownerID); err != nil {
				return err
			}
			project, err := s.repo.GetProject(ctx, db, pc.OrgID, pc.ProjectID)
			if err != nil {
				return err
			}
			count, err := s.repo.CountOwnedInProgress(ctx, db, pc.ProjectID, ownerID)
			if err != nil {
				return err
			}
			if count >= project.WipLimit {
				return ErrWipLimit
			}
		}
	case ItemInReview:
		if !skipRoleCheck && !isOwnerOrDeveloper && !isManagerPlus {
			return ErrForbidden
		}
	case ItemTesting:
		if err := SodCheck(ctx, db, item.ID, pc.UserID, SodReviewCode); err != nil {
			return err
		}
	case ItemDone:
		if err := SodCheck(ctx, db, item.ID, pc.UserID, SodSetDone); err != nil {
			return err
		}
		if !skipRoleCheck {
			tester := userWithRole(AssigneeTester)
			if tester != "" {
				if pc.UserID != tester {
					return ErrForbidden
				}
			} else if hasUserRole(pc.UserID, AssigneeDeveloper) || (!isAnyAssignee(pc.UserID) && !isManagerPlus) {
				return ErrForbidden
			}
		}
	case ItemReopened:
		if item.Status == ItemTesting {
			if err := SodCheck(ctx, db, item.ID, pc.UserID, SodTestFail); err != nil {
				return err
			}
			if !skipRoleCheck && pc.UserID != userWithRole(AssigneeTester) {
				return ErrForbidden
			}
		} else if item.Status == ItemDone && !skipRoleCheck {
			tester := userWithRole(AssigneeTester)
			isReporter := item.CreatedBy != nil && *item.CreatedBy == pc.UserID
			if pc.UserID != tester && !isReporter && !isManagerPlus {
				return ErrForbidden
			}
		}
	case ItemBlocked:
		if !skipRoleCheck && !isAnyAssignee(pc.UserID) && !isManagerPlus {
			return ErrForbidden
		}
	case ItemWontDo:
		if !skipRoleCheck && !isManagerPlus {
			return ErrForbidden
		}
	}
	return nil
}

// rollupAncestors recomputes the feature then epic status after a leaf
// changes (01 §4: "lock feature then epic after the child").
func (s *Service) rollupAncestors(ctx context.Context, tx pgx.Tx, projectID string, item *WorkItem) error {
	if item.FeatureID != nil {
		if err := s.rollupOne(ctx, tx, projectID, *item.FeatureID); err != nil {
			return err
		}
	}
	if item.EpicID != nil {
		if err := s.rollupOne(ctx, tx, projectID, *item.EpicID); err != nil {
			return err
		}
	}
	return nil
}

// rollupOne recomputes one epic/feature's status from its direct non-archived
// children. A parent already explicitly set to wont_do is left alone
// (contract-phase2.md).
func (s *Service) rollupOne(ctx context.Context, tx pgx.Tx, projectID, parentID string) error {
	parent, err := s.repo.LockWorkItem(ctx, tx, projectID, parentID)
	if err != nil {
		return err
	}
	if parent.Status == ItemWontDo {
		return nil
	}
	children, err := s.repo.ListChildStatuses(ctx, tx, parentID)
	if err != nil {
		return err
	}
	newStatus := computeRollupStatus(children)
	if newStatus == parent.Status {
		return nil
	}
	if _, err := s.repo.UpdateItemStatus(ctx, tx, projectID, parentID, newStatus, nil); err != nil {
		return fmt.Errorf("workspace: rollup: %w", err)
	}
	fromStatus := parent.Status
	return s.repo.InsertItemEvent(ctx, tx, eventInsert{
		ProjectID: projectID, ItemID: parentID, Source: SourceSystem, Kind: EventStatus,
		Field: strPtr("status"), FromValue: &fromStatus, ToValue: &newStatus,
	})
}

// computeRollupStatus applies contract-phase2.md's roll-up rule to a set of
// direct child statuses.
func computeRollupStatus(children []string) string {
	if len(children) == 0 {
		return ItemTodo
	}
	allDoneOrWontDo, anyDone, allWontDo, anyPastTodo := true, false, true, false
	for _, st := range children {
		if st != ItemDone && st != ItemWontDo {
			allDoneOrWontDo = false
		}
		if st == ItemDone {
			anyDone = true
		}
		if st != ItemWontDo {
			allWontDo = false
		}
		if st != ItemTodo {
			anyPastTodo = true
		}
	}
	switch {
	case allDoneOrWontDo && anyDone:
		return ItemDone
	case allWontDo:
		return ItemWontDo
	case anyPastTodo:
		return ItemInProgress
	default:
		return ItemTodo
	}
}
