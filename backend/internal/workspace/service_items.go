package workspace

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/pagination"
	"github.com/mindforge/backend/internal/wiki"
)

// featureSpecTemplateContent seeds a new feature's spec page (contract-
// phase3.md "Feature spec creation"): problem, scope, out of scope, API, UI,
// test plan, risks.
func featureSpecTemplateContent(title string) json.RawMessage {
	headings := []string{"Problem", "Scope", "Out of Scope", "API", "UI", "Test Plan", "Risks"}
	nodes := []map[string]any{
		{"type": "heading", "attrs": map[string]any{"level": 1}, "content": []map[string]any{{"type": "text", "text": title}}},
	}
	for _, h := range headings {
		nodes = append(nodes,
			map[string]any{"type": "heading", "attrs": map[string]any{"level": 2}, "content": []map[string]any{{"type": "text", "text": h}}},
			map[string]any{"type": "paragraph"},
		)
	}
	doc := map[string]any{"type": "doc", "content": nodes}
	raw, _ := json.Marshal(doc)
	return raw
}

// resolveItemRef parses "PREFIX-123" or a bare uuid and loads the item.
// GetWorkItem, UpdateWorkItem, MoveWorkItem etc. all accept either form
// (contract-phase2.md: "itemRef = uuid or key").
func (s *Service) resolveItemRef(ctx context.Context, db DBTX, projectID, itemRef string) (*WorkItem, error) {
	if _, err := uuid.Parse(itemRef); err == nil {
		return s.repo.GetWorkItemByID(ctx, db, projectID, itemRef)
	}
	i := strings.LastIndex(itemRef, "-")
	if i <= 0 || i == len(itemRef)-1 {
		return nil, ErrNotFound
	}
	keyNum, err := strconv.Atoi(itemRef[i+1:])
	if err != nil || keyNum <= 0 {
		return nil, ErrNotFound
	}
	return s.repo.GetWorkItemByKeyNum(ctx, db, projectID, keyNum)
}

// validateItemFields checks the field-level rules shared by create and
// update: title length, description length, priority/severity enums,
// estimate range.
func validateItemFields(fields map[string]string, title string, description *string, priority string, severity *string, itemType string, estimateMinutes *int) {
	if len(title) < 1 || len(title) > ItemTitleMaxLen {
		fields["title"] = fmt.Sprintf("Title must be 1-%d characters.", ItemTitleMaxLen)
	}
	if description != nil && len(*description) > ItemDescriptionMaxLen {
		fields["description"] = fmt.Sprintf("Description must be %d characters or fewer.", ItemDescriptionMaxLen)
	}
	if !contains(ItemPriorities, priority) {
		fields["priority"] = "Priority must be one of low, medium, high, urgent."
	}
	if severity != nil {
		if itemType != ItemTypeBug {
			fields["severity"] = "Only bugs may have a severity."
		} else if !contains(BugSeverities, *severity) {
			fields["severity"] = "Severity must be one of S1, S2, S3, S4."
		}
	}
	if estimateMinutes != nil && (*estimateMinutes < 1 || *estimateMinutes > 100000) {
		fields["estimate_minutes"] = "Estimate must be between 1 and 100000 minutes."
	}
}

func contains(list []string, v string) bool {
	for _, x := range list {
		if x == v {
			return true
		}
	}
	return false
}

// deriveAncestors computes epic_id/feature_id for a new/moved item from its
// parent, matching 037's own CHECK constraints: an epic never carries
// epic_id/feature_id; a feature carries epic_id (pointing at its own parent
// epic) but never feature_id; everything else inherits both from the parent.
func deriveAncestors(parent *WorkItem) (epicID, featureID *string) {
	if parent == nil {
		return nil, nil
	}
	switch parent.Type {
	case ItemTypeEpic:
		id := parent.ID
		return &id, nil
	case ItemTypeFeature:
		id := parent.ID
		return parent.EpicID, &id
	default:
		return parent.EpicID, parent.FeatureID
	}
}

// CreateWorkItem validates req, checks the caller's role against the item
// type being created, derives the hierarchy pointers and key, and inserts
// the item plus its `create` event in one transaction (contract-phase2.md
// "Create").
func (s *Service) CreateWorkItem(ctx context.Context, pc *ProjectCtx, req CreateWorkItemRequest) (*CreateWorkItemResult, error) {
	if !contains([]string{ItemTypeEpic, ItemTypeFeature, ItemTypeTask, ItemTypeBug, ItemTypeSubtask}, req.Type) {
		return nil, fmt.Errorf("%w: unknown item type %q", ErrInvalidInput, req.Type)
	}
	title := strings.TrimSpace(req.Title)
	priority := req.Priority
	if priority == "" {
		priority = "medium"
	}
	var description *string
	if req.Description != nil {
		d := strings.TrimSpace(*req.Description)
		if d != "" {
			description = &d
		}
	}
	fields := map[string]string{}
	validateItemFields(fields, title, description, priority, req.Severity, req.Type, req.EstimateMinutes)
	if len(fields) > 0 {
		return nil, &FieldError{Fields: fields}
	}

	var result *CreateWorkItemResult
	err := s.repo.InTx(ctx, func(tx pgx.Tx) error {
		var parent *WorkItem
		var err error
		if req.ParentID != nil {
			parent, err = s.repo.GetWorkItemByID(ctx, tx, pc.ProjectID, *req.ParentID)
			if err != nil {
				return err
			}
		}
		parentType := ""
		if parent != nil {
			parentType = parent.Type
		}
		if !ChildAllowed(parentType, req.Type) {
			return ErrIllegalHierarchy
		}

		switch req.Type {
		case ItemTypeEpic:
			if !RoleAtLeast(pc.Role, RoleManager) {
				return ErrForbidden
			}
		case ItemTypeFeature:
			if !RoleAtLeast(pc.Role, RoleManager) {
				if req.TrackID == nil {
					return ErrForbidden
				}
				lead, err := s.repo.IsTrackLead(ctx, tx, pc.ProjectID, *req.TrackID, pc.UserID)
				if err != nil {
					return err
				}
				if !lead {
					return ErrForbidden
				}
			}
		}

		epicID, featureID := deriveAncestors(parent)

		trackID := req.TrackID
		if trackID == nil && (req.Type == ItemTypeTask || req.Type == ItemTypeBug || req.Type == ItemTypeSubtask) && parent != nil {
			trackID = parent.TrackID
		}
		if trackID != nil {
			if _, err := s.repo.GetTrack(ctx, tx, pc.ProjectID, *trackID); err != nil {
				return err
			}
		}

		keyNum, _, err := s.repo.BumpItemSeq(ctx, tx, pc.ProjectID)
		if err != nil {
			return err
		}

		var parentIDPtr *string
		if parent != nil {
			parentIDPtr = &parent.ID
		}
		createdBy := pc.UserID
		item, err := s.repo.InsertWorkItem(ctx, tx, pc.ProjectID, keyNum, itemInsert{
			Type: req.Type, ParentID: parentIDPtr, EpicID: epicID, FeatureID: featureID, TrackID: trackID,
			Title: title, Description: description, Priority: priority, Severity: req.Severity,
			EstimateMinutes: req.EstimateMinutes, DueAt: req.DueAt, CreatedBy: createdBy,
		})
		if err != nil {
			return fmt.Errorf("workspace: create work item: insert: %w", err)
		}

		if err := s.repo.InsertItemEvent(ctx, tx, eventInsert{
			ProjectID: pc.ProjectID, ItemID: item.ID, ActorID: &createdBy, Source: SourceUser, Kind: EventCreate,
			ToValue: &item.Status,
		}); err != nil {
			return err
		}

		// contract-phase3.md "Feature spec creation": every feature gets a
		// doc-gated spec page in the project space, same tx as the item itself.
		if req.Type == ItemTypeFeature {
			spaceID, _, err := s.repo.GetProjectWikiSpace(ctx, tx, pc.ProjectID)
			if err != nil {
				return err
			}
			if spaceID != nil {
				content := featureSpecTemplateContent(title)
				slug := courses.Slugify(item.Key + "-" + title)
				page, err := wiki.CreatePageTx(ctx, tx, *spaceID, title, slug, nil, nil, content, title, createdBy)
				if err != nil {
					return fmt.Errorf("workspace: create work item: spec page: %w", err)
				}
				if err := s.repo.SetItemDocPage(ctx, tx, pc.ProjectID, item.ID, page.ID); err != nil {
					return err
				}
				item.DocWikiPageID, item.DocStatus = &page.ID, strPtr(DocDraft)
			}
		}

		similar, err := s.repo.ListSimilarItems(ctx, tx, pc.ProjectID, title, item.ID)
		if err != nil {
			return err
		}

		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_item.created", "work_item", item.ID, map[string]string{"key": item.Key, "type": item.Type})
		result = &CreateWorkItemResult{Item: *item, Similar: similar}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}

// GetWorkItem assembles the full detail view: the row, its parent/children,
// links, and the transitions the caller may make right now versus the ones
// that are machine-legal but currently locked (contract: "computed by the
// same rule code the transition uses").
func (s *Service) GetWorkItem(ctx context.Context, pc *ProjectCtx, itemRef string) (*ItemDetail, error) {
	item, err := s.resolveItemRef(ctx, s.pool, pc.ProjectID, itemRef)
	if err != nil {
		return nil, err
	}
	assignees, err := s.repo.ListAssigneesByItem(ctx, s.pool, item.ID)
	if err != nil {
		return nil, err
	}
	item.Assignees = assignees

	var parent *ItemRef
	if item.ParentID != nil {
		parent, err = s.repo.GetItemRef(ctx, s.pool, pc.ProjectID, *item.ParentID)
		if err != nil && err != ErrNotFound {
			return nil, err
		}
	}
	children, err := s.repo.ListChildRefs(ctx, s.pool, pc.ProjectID, item.ID)
	if err != nil {
		return nil, err
	}
	links, err := s.repo.ListItemLinks(ctx, s.pool, pc.ProjectID, item.ID)
	if err != nil {
		return nil, err
	}

	detail := &ItemDetail{
		WorkItem: *item, Parent: parent, Children: children, Links: links,
		LegalTransitions: []string{}, LockedTransitions: map[string]string{},
	}

	if !IsRollupType(item.Type) {
		for _, to := range WorkItemStatusMachine.Next(item.Status) {
			if gateErr := s.checkTransitionGate(ctx, s.pool, pc, item, to, false); gateErr != nil {
				detail.LockedTransitions[to] = gateErr.Error()
			} else {
				detail.LegalTransitions = append(detail.LegalTransitions, to)
			}
		}
	} else if item.Status != ItemWontDo && RoleAtLeast(pc.Role, RoleManager) {
		detail.LegalTransitions = append(detail.LegalTransitions, ItemWontDo)
	}

	editors, err := s.canEditItem(ctx, s.pool, pc, item)
	if err != nil {
		return nil, err
	}
	detail.CanEdit = editors
	canDeleteRole := RoleAtLeast(pc.Role, RoleManager) || (item.CreatedBy != nil && *item.CreatedBy == pc.UserID)
	detail.CanDelete = item.Status == ItemTodo && canDeleteRole && s.isOnlyCreateEvent(ctx, item.ID)
	return detail, nil
}

// isOnlyCreateEvent is CanDelete's cheap preview — the authoritative check
// happens again inside DeleteWorkItem's transaction.
func (s *Service) isOnlyCreateEvent(ctx context.Context, itemID string) bool {
	n, err := s.repo.CountItemEvents(ctx, s.pool, itemID)
	return err == nil && n <= 1
}

// canEditItem mirrors Update's own editor rule: creator, any assignee,
// manager+, or lead of the item's track.
func (s *Service) canEditItem(ctx context.Context, db DBTX, pc *ProjectCtx, item *WorkItem) (bool, error) {
	if RoleAtLeast(pc.Role, RoleManager) {
		return true, nil
	}
	if item.CreatedBy != nil && *item.CreatedBy == pc.UserID {
		return true, nil
	}
	for _, a := range item.Assignees {
		if a.UserID == pc.UserID {
			return true, nil
		}
	}
	if item.TrackID != nil {
		lead, err := s.repo.IsTrackLead(ctx, db, pc.ProjectID, *item.TrackID, pc.UserID)
		if err != nil {
			return false, err
		}
		return lead, nil
	}
	return false, nil
}

// ListWorkItems applies ItemFilter with cursor pagination and batch-loads
// assignees for the page.
func (s *Service) ListWorkItems(ctx context.Context, pc *ProjectCtx, f ItemFilter) (Page[WorkItem], error) {
	limit := clampLimit(f.Limit)
	cursorAt, cursorID, err := pagination.DecodeCursor(f.Cursor, "workspace_items")
	if err != nil {
		cursorAt, cursorID = time.Time{}, ""
	}
	items, err := s.repo.ListWorkItems(ctx, s.pool, pc.ProjectID, f, cursorAt, cursorID, limit+1)
	if err != nil {
		return Page[WorkItem]{}, err
	}
	page := Page[WorkItem]{Items: items}
	if len(items) > limit {
		page.Items = items[:limit]
		last := page.Items[limit-1]
		page.NextCursor = pagination.EncodeCursor(last.CreatedAt, last.ID)
	}
	ids := make([]string, len(page.Items))
	for i := range page.Items {
		ids[i] = page.Items[i].ID
	}
	byItem, err := s.repo.ListAssigneesForItems(ctx, s.pool, ids)
	if err != nil {
		return Page[WorkItem]{}, err
	}
	for i := range page.Items {
		if a, ok := byItem[page.Items[i].ID]; ok {
			page.Items[i].Assignees = a
		}
	}
	return page, nil
}

// UpdateWorkItem applies a partial PATCH under the optimistic version lock.
// A paused project only allows a description change (route gate is
// StatusesDiscuss which includes paused; the description-only restriction is
// enforced here since the gate can't express it).
func (s *Service) UpdateWorkItem(ctx context.Context, pc *ProjectCtx, itemID string, req UpdateWorkItemRequest) (*WorkItem, error) {
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
	if pc.ProjectStatus == ProjectPaused {
		onlyDescription := req.Title == nil && req.Priority == nil && req.Severity == nil && req.IsRegression == nil &&
			req.EstimateMinutes == nil && !req.ClearEstimate && req.DueAt == nil && !req.ClearDueAt && req.TrackID == nil && !req.ClearTrack
		if !onlyDescription {
			return nil, fmt.Errorf("%w: only the description can change while the project is paused", ErrInvalidState)
		}
	}

	title := current.Title
	if req.Title != nil {
		title = strings.TrimSpace(*req.Title)
	}
	description := current.Description
	if req.Description != nil {
		d := strings.TrimSpace(*req.Description)
		if d == "" {
			description = nil
		} else {
			description = &d
		}
	}
	priority := current.Priority
	if req.Priority != nil {
		priority = *req.Priority
	}
	severity := current.Severity
	if req.Severity != nil {
		severity = req.Severity
	}
	isRegression := current.IsRegression
	if req.IsRegression != nil {
		isRegression = *req.IsRegression
	}
	estimate := current.EstimateMinutes
	if req.ClearEstimate {
		estimate = nil
	} else if req.EstimateMinutes != nil {
		estimate = req.EstimateMinutes
	}
	dueAt := current.DueAt
	if req.ClearDueAt {
		dueAt = nil
	} else if req.DueAt != nil {
		dueAt = req.DueAt
	}
	trackID := current.TrackID
	if req.ClearTrack {
		trackID = nil
	} else if req.TrackID != nil {
		trackID = req.TrackID
	}

	fields := map[string]string{}
	validateItemFields(fields, title, description, priority, severity, current.Type, estimate)
	if len(fields) > 0 {
		return nil, &FieldError{Fields: fields}
	}
	if trackID != nil {
		if _, err := s.repo.GetTrack(ctx, s.pool, pc.ProjectID, *trackID); err != nil {
			return nil, err
		}
	}

	var updated *WorkItem
	err = s.repo.InTx(ctx, func(tx pgx.Tx) error {
		u, err := s.repo.UpdateItemFields(ctx, tx, pc.ProjectID, itemID, req.Version, title, description, priority, severity, isRegression, estimate, dueAt, trackID)
		if err != nil {
			if err == ErrNotFound {
				fresh, freshErr := s.repo.GetWorkItemByID(ctx, tx, pc.ProjectID, itemID)
				if freshErr != nil {
					return freshErr
				}
				return &ConflictError{Current: fresh}
			}
			return err
		}
		actor := pc.UserID
		fieldEvent := func(field string, from, to *string) error {
			if from == nil && to == nil {
				return nil
			}
			if from != nil && to != nil && *from == *to {
				return nil
			}
			return s.repo.InsertItemEvent(ctx, tx, eventInsert{
				ProjectID: pc.ProjectID, ItemID: itemID, ActorID: &actor, Source: SourceUser, Kind: EventField,
				Field: strPtr(field), FromValue: from, ToValue: to,
			})
		}
		if err := fieldEvent("title", &current.Title, &title); err != nil {
			return err
		}
		if err := fieldEvent("description", current.Description, description); err != nil {
			return err
		}
		if err := fieldEvent("priority", &current.Priority, &priority); err != nil {
			return err
		}
		if err := fieldEvent("severity", current.Severity, severity); err != nil {
			return err
		}
		if err := fieldEvent("track_id", current.TrackID, trackID); err != nil {
			return err
		}
		if err := fieldEvent("estimate_minutes", intPtrToStr(current.EstimateMinutes), intPtrToStr(estimate)); err != nil {
			return err
		}
		if err := fieldEvent("due_at", timePtrToStr(current.DueAt), timePtrToStr(dueAt)); err != nil {
			return err
		}
		if err := fieldEvent("is_regression", strPtr(strconv.FormatBool(current.IsRegression)), strPtr(strconv.FormatBool(isRegression))); err != nil {
			return err
		}
		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_item.updated", "work_item", itemID, nil)
		updated = u
		return nil
	})
	if err != nil {
		return nil, err
	}
	return updated, nil
}

func strPtr(s string) *string { return &s }

func intPtrToStr(n *int) *string {
	if n == nil {
		return nil
	}
	return strPtr(strconv.Itoa(*n))
}

func timePtrToStr(t *time.Time) *string {
	if t == nil {
		return nil
	}
	return strPtr(t.UTC().Format(time.RFC3339))
}

// MoveWorkItem re-parents an item, recomputing epic_id/feature_id for it and
// every descendant under the project graph lock (01 §4's canonical lock
// order: project graph lock before the item rows).
func (s *Service) MoveWorkItem(ctx context.Context, pc *ProjectCtx, itemID string, req MoveWorkItemRequest) (*WorkItem, error) {
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

	var updated *WorkItem
	err = s.repo.InTx(ctx, func(tx pgx.Tx) error {
		if err := s.repo.LockItemGraph(ctx, tx, pc.ProjectID); err != nil {
			return err
		}
		var parent *WorkItem
		if req.ParentID != nil {
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
		if !ChildAllowed(parentType, current.Type) {
			return ErrIllegalHierarchy
		}
		epicID, featureID := deriveAncestors(parent)

		u, err := s.repo.UpdateItemParent(ctx, tx, pc.ProjectID, itemID, req.Version, req.ParentID, epicID, featureID)
		if err != nil {
			if err == ErrNotFound {
				fresh, freshErr := s.repo.GetWorkItemByID(ctx, tx, pc.ProjectID, itemID)
				if freshErr != nil {
					return freshErr
				}
				return &ConflictError{Current: fresh}
			}
			return err
		}
		if err := s.repo.UpdateDescendantAncestors(ctx, tx, pc.ProjectID, itemID, epicID, featureID); err != nil {
			return err
		}
		actor := pc.UserID
		var fromParent, toParent *string
		if current.ParentID != nil {
			fromParent = current.ParentID
		}
		if req.ParentID != nil {
			toParent = req.ParentID
		}
		if err := s.repo.InsertItemEvent(ctx, tx, eventInsert{
			ProjectID: pc.ProjectID, ItemID: itemID, ActorID: &actor, Source: SourceUser, Kind: EventParent,
			FromValue: fromParent, ToValue: toParent,
		}); err != nil {
			return err
		}
		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_item.moved", "work_item", itemID, nil)
		updated = u
		return nil
	})
	if err != nil {
		return nil, err
	}
	return updated, nil
}

// ArchiveWorkItem sets archived_at (creator or manager+, and never while it
// still has non-archived children).
func (s *Service) ArchiveWorkItem(ctx context.Context, pc *ProjectCtx, itemID string) error {
	item, err := s.repo.GetWorkItemByID(ctx, s.pool, pc.ProjectID, itemID)
	if err != nil {
		return err
	}
	if !RoleAtLeast(pc.Role, RoleManager) && (item.CreatedBy == nil || *item.CreatedBy != pc.UserID) {
		return ErrForbidden
	}
	children, err := s.repo.CountNonArchivedChildren(ctx, s.pool, itemID)
	if err != nil {
		return err
	}
	if children > 0 {
		return fmt.Errorf("%w: archive or move its children first", ErrPreconditionFail)
	}
	return s.repo.InTx(ctx, func(tx pgx.Tx) error {
		if err := s.repo.ArchiveItem(ctx, tx, pc.ProjectID, itemID); err != nil {
			return err
		}
		actor := pc.UserID
		if err := s.repo.InsertItemEvent(ctx, tx, eventInsert{
			ProjectID: pc.ProjectID, ItemID: itemID, ActorID: &actor, Source: SourceUser, Kind: EventArchive,
		}); err != nil {
			return err
		}
		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_item.archived", "work_item", itemID, nil)
		return nil
	})
}

// DeleteWorkItem hard-deletes a `todo` item that has never left that state —
// exactly one `create` event, by its creator or manager+ (contract: "only
// todo items with no history"). Everything else must be archived instead.
func (s *Service) DeleteWorkItem(ctx context.Context, pc *ProjectCtx, itemID string) error {
	item, err := s.repo.GetWorkItemByID(ctx, s.pool, pc.ProjectID, itemID)
	if err != nil {
		return err
	}
	if !RoleAtLeast(pc.Role, RoleManager) && (item.CreatedBy == nil || *item.CreatedBy != pc.UserID) {
		return ErrForbidden
	}
	if item.Status != ItemTodo {
		return ErrNotDeletable
	}
	n, err := s.repo.CountItemEvents(ctx, s.pool, itemID)
	if err != nil {
		return err
	}
	if n > 1 {
		return ErrNotDeletable
	}
	return s.repo.InTx(ctx, func(tx pgx.Tx) error {
		fresh, err := s.repo.LockWorkItem(ctx, tx, pc.ProjectID, itemID)
		if err != nil {
			return err
		}
		if fresh.Status != ItemTodo {
			return ErrNotDeletable
		}
		freshN, err := s.repo.CountItemEvents(ctx, tx, itemID)
		if err != nil {
			return err
		}
		if freshN > 1 {
			return ErrNotDeletable
		}
		if err := s.repo.DeleteItem(ctx, tx, pc.ProjectID, itemID); err != nil {
			return err
		}
		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_item.deleted", "work_item", itemID, map[string]string{"key": item.Key})
		return nil
	})
}

// ListSimilarItems is the standalone duplicate-check endpoint (create-item
// dialog's debounced search).
func (s *Service) ListSimilarItems(ctx context.Context, pc *ProjectCtx, q string) ([]SimilarItem, error) {
	q = strings.TrimSpace(q)
	if len(q) < 1 || len(q) > SimilarQueryMaxLen {
		return nil, fmt.Errorf("%w: q must be 1-%d characters", ErrInvalidInput, SimilarQueryMaxLen)
	}
	if allowed, retryAfter := s.limiter.Allow(ctx, "rl:pw:similar:"+pc.UserID, s.cfg.Workspace.SimilarPerUserMinute, time.Minute); !allowed {
		return nil, &RateLimitError{RetryAfter: retryAfter}
	}
	var out []SimilarItem
	err := s.repo.InTx(ctx, func(tx pgx.Tx) error {
		items, err := s.repo.ListSimilarItems(ctx, tx, pc.ProjectID, q, "")
		if err != nil {
			return err
		}
		out = items
		return nil
	})
	return out, err
}

// ListItemEvents cursor-paginates one item's timeline.
func (s *Service) ListItemEvents(ctx context.Context, pc *ProjectCtx, itemID, cursor string, limit int) (Page[ItemEvent], error) {
	if _, err := s.repo.GetWorkItemByID(ctx, s.pool, pc.ProjectID, itemID); err != nil {
		return Page[ItemEvent]{}, err
	}
	limit = clampLimit(limit)
	before := beforeIDFromCursor(cursor)
	events, err := s.repo.ListItemEvents(ctx, s.pool, pc.ProjectID, itemID, before, limit+1)
	if err != nil {
		return Page[ItemEvent]{}, err
	}
	page := Page[ItemEvent]{Items: events}
	if len(events) > limit {
		page.Items = events[:limit]
		page.NextCursor = cursorFromID(page.Items[limit-1].ID)
	}
	return page, nil
}
