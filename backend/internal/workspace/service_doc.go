package workspace

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"

	"github.com/mindforge/backend/internal/notifications"
)

// service_doc.go — the feature-spec review gate (contract-phase3.md "SubmitDoc"
// / "ReviewDoc" / "Change request" / design review scheduling).

// isFeatureActor reports whether pc may act as the feature's own
// owner/developer/creator/manager+ (SubmitDoc's actor rule).
func isFeatureActor(pc *ProjectCtx, item *WorkItem) bool {
	if RoleAtLeast(pc.Role, RoleManager) {
		return true
	}
	if item.CreatedBy != nil && *item.CreatedBy == pc.UserID {
		return true
	}
	for _, a := range item.Assignees {
		if a.UserID == pc.UserID && (a.Role == AssigneeOwner || a.Role == AssigneeDeveloper) {
			return true
		}
	}
	return false
}

func reviewerIDs(assignees []Assignee) []string {
	out := []string{}
	for _, a := range assignees {
		if a.Role == AssigneeReviewer {
			out = append(out, a.UserID)
		}
	}
	return out
}

func isCurrentReviewer(assignees []Assignee, userID string) bool {
	for _, a := range assignees {
		if a.UserID == userID && a.Role == AssigneeReviewer {
			return true
		}
	}
	return false
}

// GetDoc is GET …/items/{itemID}/doc.
func (s *Service) GetDoc(ctx context.Context, pc *ProjectCtx, itemID string) (*DocView, error) {
	item, err := s.repo.GetWorkItemByID(ctx, s.pool, pc.ProjectID, itemID)
	if err != nil {
		return nil, err
	}
	if item.Type != ItemTypeFeature {
		return nil, fmt.Errorf("%w: only features have a spec", ErrInvalidInput)
	}
	item.Assignees, err = s.repo.ListAssigneesByItem(ctx, s.pool, item.ID)
	if err != nil {
		return nil, err
	}
	view := &DocView{ItemID: item.ID, DocStatus: item.DocStatus, ApprovedDocVersion: item.ApprovedDocVersion, Reviewers: []Assignee{}}
	for _, a := range item.Assignees {
		if a.Role == AssigneeReviewer {
			view.Reviewers = append(view.Reviewers, a)
		}
	}
	if item.DocWikiPageID == nil {
		view.Reviews = []ItemReview{}
		return view, nil
	}
	view.PageID = item.DocWikiPageID
	slug, spaceSlug, version, err := s.repo.GetWikiPageInfo(ctx, s.pool, *item.DocWikiPageID)
	if err != nil {
		return nil, err
	}
	view.PageSlug, view.SpaceSlug, view.PageVersion = &slug, &spaceSlug, version
	view.ChangedSinceApproval = item.SpecChangedAt != nil || (item.ApprovedDocVersion != nil && version > *item.ApprovedDocVersion)

	reviews, err := s.repo.ListItemReviews(ctx, s.pool, item.ID, ReviewTargetDoc)
	if err != nil {
		return nil, err
	}
	view.Reviews = reviews
	return view, nil
}

// SubmitDoc moves a feature's spec into review (contract-phase3.md "SubmitDoc").
func (s *Service) SubmitDoc(ctx context.Context, pc *ProjectCtx, itemID string) (*DocView, error) {
	err := s.repo.InTx(ctx, func(tx pgx.Tx) error {
		item, err := s.repo.LockWorkItem(ctx, tx, pc.ProjectID, itemID)
		if err != nil {
			return err
		}
		if item.Type != ItemTypeFeature || item.DocWikiPageID == nil || item.DocStatus == nil {
			return fmt.Errorf("%w: only features have a spec", ErrInvalidInput)
		}
		item.Assignees, err = s.repo.ListAssigneesByItem(ctx, tx, item.ID)
		if err != nil {
			return err
		}
		if !isFeatureActor(pc, item) {
			return ErrForbidden
		}
		reviewers := reviewerIDs(item.Assignees)
		if len(reviewers) == 0 {
			return ErrNoReviewers
		}
		if !DocStatusMachine.Allowed(*item.DocStatus, DocInReview) {
			return ErrIllegalTransition
		}
		if _, err := s.repo.SetDocStatus(ctx, tx, pc.ProjectID, item.ID, DocInReview, nil, false); err != nil {
			return err
		}
		actor := pc.UserID
		reason := "submitted for review"
		if err := s.repo.InsertItemEvent(ctx, tx, eventInsert{
			ProjectID: pc.ProjectID, ItemID: item.ID, ActorID: &actor, Source: SourceUser, Kind: EventDoc, Reason: &reason,
		}); err != nil {
			return err
		}
		body := fmt.Sprintf("%s's spec is ready for your review.", item.Key)
		if err := s.notif.NotifyMany(ctx, tx, notifications.New{
			OrgID: pc.OrgID, Type: "workspace_doc_submitted", Title: "Spec ready for review", Body: &body,
			EntityType: strPtr("work_item"), EntityID: &item.ID, DedupeKey: fmt.Sprintf("workspace_doc_submitted:%s:%d", item.ID, item.Version),
		}, reviewers); err != nil {
			return fmt.Errorf("workspace: submit doc: notify reviewers: %w", err)
		}
		writeAudit(ctx, tx, pc.OrgID, &actor, "workspace_doc.submitted", "work_item", item.ID, nil)
		return nil
	})
	if err != nil {
		return nil, err
	}
	return s.GetDoc(ctx, pc, itemID)
}

// ReviewDoc records one verdict on a feature's spec at its current wiki
// version (contract-phase3.md "ReviewDoc").
func (s *Service) ReviewDoc(ctx context.Context, pc *ProjectCtx, itemID string, req ReviewDocRequest) (*DocView, error) {
	if !contains([]string{VerdictApproved, VerdictChangesRequested, VerdictCommented}, req.Verdict) {
		return nil, fmt.Errorf("%w: verdict must be approved, changes_requested, or commented", ErrInvalidInput)
	}
	if req.Verdict == VerdictChangesRequested && (req.Comment == nil || strings.TrimSpace(*req.Comment) == "") {
		return nil, &FieldError{Fields: map[string]string{"comment": "A comment is required when requesting changes."}}
	}
	if req.Comment != nil && len(*req.Comment) > ReviewCommentMaxLen {
		return nil, &FieldError{Fields: map[string]string{"comment": fmt.Sprintf("Comment must be %d characters or fewer.", ReviewCommentMaxLen)}}
	}

	err := s.repo.InTx(ctx, func(tx pgx.Tx) error {
		item, err := s.repo.LockWorkItem(ctx, tx, pc.ProjectID, itemID)
		if err != nil {
			return err
		}
		if item.Type != ItemTypeFeature || item.DocWikiPageID == nil || item.DocStatus == nil {
			return fmt.Errorf("%w: only features have a spec", ErrInvalidInput)
		}
		item.Assignees, err = s.repo.ListAssigneesByItem(ctx, tx, item.ID)
		if err != nil {
			return err
		}
		if !isCurrentReviewer(item.Assignees, pc.UserID) && !RoleAtLeast(pc.Role, RoleManager) {
			return ErrForbidden
		}
		_, _, currentVersion, err := s.repo.GetWikiPageInfo(ctx, tx, *item.DocWikiPageID)
		if err != nil {
			return err
		}
		if req.WikiVersion != currentVersion {
			return ErrStaleDocVersion
		}
		if req.Verdict == VerdictApproved {
			if err := SodCheck(ctx, tx, item.ID, pc.UserID, SodApproveDoc); err != nil {
				return err
			}
		}

		reviewerID := pc.UserID
		if _, err := s.repo.InsertDocReview(ctx, tx, pc.ProjectID, item.ID, reviewerID, req.Verdict, req.Comment, req.WikiVersion); err != nil {
			return err
		}
		actor := pc.UserID
		if err := s.repo.InsertItemEvent(ctx, tx, eventInsert{
			ProjectID: pc.ProjectID, ItemID: item.ID, ActorID: &actor, Source: SourceUser, Kind: EventReview,
			Field: strPtr(ReviewTargetDoc), ToValue: strPtr(req.Verdict), Reason: req.Comment,
		}); err != nil {
			return err
		}

		switch req.Verdict {
		case VerdictChangesRequested:
			if _, err := s.repo.SetDocStatus(ctx, tx, pc.ProjectID, item.ID, DocChangesRequested, nil, false); err != nil {
				return err
			}
			reason := "changes requested"
			if err := s.repo.InsertItemEvent(ctx, tx, eventInsert{
				ProjectID: pc.ProjectID, ItemID: item.ID, ActorID: &actor, Source: SourceUser, Kind: EventDoc, Reason: &reason,
			}); err != nil {
				return err
			}
		case VerdictApproved:
			allApproved, err := s.repo.AllCurrentReviewersApproved(ctx, tx, item.ID, req.WikiVersion)
			if err != nil {
				return err
			}
			if allApproved {
				version := req.WikiVersion
				if _, err := s.repo.SetDocStatus(ctx, tx, pc.ProjectID, item.ID, DocApproved, &version, true); err != nil {
					return err
				}
				if err := s.repo.ClearChildTasksSpecChanged(ctx, tx, pc.ProjectID, item.ID); err != nil {
					return err
				}
				reason := "approved"
				if err := s.repo.InsertItemEvent(ctx, tx, eventInsert{
					ProjectID: pc.ProjectID, ItemID: item.ID, ActorID: &actor, Source: SourceUser, Kind: EventDoc, Reason: &reason,
				}); err != nil {
					return err
				}
			}
		}
		writeAudit(ctx, tx, pc.OrgID, &actor, "workspace_doc.reviewed", "work_item", item.ID, map[string]string{"verdict": req.Verdict})
		return nil
	})
	if err != nil {
		return nil, err
	}
	return s.GetDoc(ctx, pc, itemID)
}

// RequestDocChange is wired to wiki.SetPageUpdateHook at startup
// (internal/api/router.go): a feature spec page edited after its doc was
// approved reopens the doc gate (contract-phase3.md "Change request", Flow
// F). It runs inside the wiki page's own UpdatePage transaction, so a
// notification insert here commits/rolls back atomically with the edit
// itself rather than a separate best-effort pass.
func (s *Service) RequestDocChange(ctx context.Context, tx pgx.Tx, pageID, userID string, newVersion int) error {
	feature, err := s.repo.GetFeatureByDocPage(ctx, tx, pageID)
	if errors.Is(err, ErrNotFound) {
		return nil
	}
	if err != nil {
		return err
	}
	if feature.DocStatus == nil || *feature.DocStatus != DocApproved {
		return nil
	}
	if feature.ApprovedDocVersion != nil && newVersion <= *feature.ApprovedDocVersion {
		return nil
	}
	if _, err := s.repo.SetDocStatus(ctx, tx, feature.ProjectID, feature.ID, DocInReview, nil, false); err != nil {
		return err
	}
	if err := s.repo.MarkChildTasksSpecChanged(ctx, tx, feature.ProjectID, feature.ID); err != nil {
		return err
	}
	reason := "spec changed after approval"
	if err := s.repo.InsertItemEvent(ctx, tx, eventInsert{
		ProjectID: feature.ProjectID, ItemID: feature.ID, ActorID: &userID, Source: SourceUser, Kind: EventDoc, Reason: &reason,
	}); err != nil {
		return err
	}
	assignees, err := s.repo.ListAssigneesByItem(ctx, tx, feature.ID)
	if err != nil {
		return err
	}
	reviewers := reviewerIDs(assignees)
	if len(reviewers) == 0 {
		return nil
	}
	orgID, err := s.repo.GetProjectOrgID(ctx, tx, feature.ProjectID)
	if err != nil {
		return err
	}
	body := fmt.Sprintf("%s's approved spec changed — please review it again.", feature.Key)
	if err := s.notif.NotifyMany(ctx, tx, notifications.New{
		OrgID: orgID, Type: "workspace_doc_changed", Title: "Approved spec changed", Body: &body,
		EntityType: strPtr("work_item"), EntityID: &feature.ID, DedupeKey: fmt.Sprintf("workspace_doc_changed:%s:%d", feature.ID, newVersion),
	}, reviewers); err != nil {
		return fmt.Errorf("workspace: request doc change: notify reviewers: %w", err)
	}
	return nil
}

// ScheduleDesignReview schedules a design_review meeting for a feature, with
// its current reviewers as attendees (contract-phase3.md "Meetings").
func (s *Service) ScheduleDesignReview(ctx context.Context, pc *ProjectCtx, itemID string, req ScheduleMeetingRequest) (*Meeting, error) {
	item, err := s.repo.GetWorkItemByID(ctx, s.pool, pc.ProjectID, itemID)
	if err != nil {
		return nil, err
	}
	if item.Type != ItemTypeFeature {
		return nil, fmt.Errorf("%w: design review requires a feature", ErrInvalidInput)
	}
	assignees, err := s.repo.ListAssigneesByItem(ctx, s.pool, item.ID)
	if err != nil {
		return nil, err
	}
	item.Assignees = assignees
	if !isFeatureActor(pc, item) {
		return nil, ErrForbidden
	}

	attendees := map[string]bool{}
	for _, id := range req.AttendeeIDs {
		attendees[id] = true
	}
	for _, id := range reviewerIDs(assignees) {
		attendees[id] = true
	}
	merged := make([]string, 0, len(attendees))
	for id := range attendees {
		merged = append(merged, id)
	}

	req.Kind = "design_review"
	req.ItemID = &item.ID
	req.AttendeeIDs = merged
	return s.scheduleMeetingTx(ctx, pc, req)
}
