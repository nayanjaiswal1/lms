package workspace

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5"

	"github.com/mindforge/backend/internal/db"
	"github.com/mindforge/backend/internal/notifications"
)

var linkKinds = []string{LinkBlocks, LinkRelates, LinkDuplicates}

// ensureBlocksLink creates the blocker→item `blocks` link if it isn't there
// already, cycle-checked under the project graph lock (01 §4) — shared by
// CreateLink's own blocks path and the `blocked` transition (which must
// create this link per contract-phase2.md).
func (s *Service) ensureBlocksLink(ctx context.Context, tx pgx.Tx, projectID, fromID, toID, createdBy string) error {
	if err := s.repo.LockItemGraph(ctx, tx, projectID); err != nil {
		return err
	}
	exists, err := s.repo.LinkExists(ctx, tx, fromID, toID, LinkBlocks)
	if err != nil {
		return err
	}
	if exists {
		return nil
	}
	edges, err := s.repo.LoadBlocksEdges(ctx, tx, projectID)
	if err != nil {
		return err
	}
	// Would fromID -> toID close a loop? Equivalent to: can toID already
	// reach fromID over existing blocks edges (01 §4's recursive-CTE rule,
	// restated as the shared DFS statemachine.HasPath documents).
	if HasPath(edges, toID, fromID) {
		return ErrLinkCycle
	}
	if err := s.repo.InsertLink(ctx, tx, projectID, fromID, toID, LinkBlocks, createdBy); err != nil {
		if db.IsUniqueViolation(err) {
			return nil // race: another request just inserted the same edge
		}
		return fmt.Errorf("workspace: ensure blocks link: %w", err)
	}
	actor := createdBy
	return s.repo.InsertItemEvent(ctx, tx, eventInsert{
		ProjectID: projectID, ItemID: fromID, ActorID: &actor, Source: SourceUser, Kind: EventLink, ToValue: strPtr(LinkBlocks),
	})
}

// CreateLink adds a blocks/relates/duplicates edge from itemID to
// req.ToItemID (contract-phase2.md "Links").
func (s *Service) CreateLink(ctx context.Context, pc *ProjectCtx, itemID string, req CreateLinkRequest) (*ItemLink, error) {
	if !contains(linkKinds, req.Kind) {
		return nil, fmt.Errorf("%w: kind must be blocks, relates, or duplicates", ErrInvalidInput)
	}
	if req.ToItemID == itemID {
		return nil, fmt.Errorf("%w: an item can't link to itself", ErrInvalidInput)
	}
	from, err := s.repo.GetWorkItemByID(ctx, s.pool, pc.ProjectID, itemID)
	if err != nil {
		return nil, err
	}
	to, err := s.repo.GetWorkItemByID(ctx, s.pool, pc.ProjectID, req.ToItemID)
	if err != nil {
		return nil, err
	}

	isDuplicate := req.Kind == LinkDuplicates
	var link *ItemLink
	err = s.repo.InTx(ctx, func(tx pgx.Tx) error {
		switch req.Kind {
		case LinkBlocks:
			if err := s.repo.LockItemGraph(ctx, tx, pc.ProjectID); err != nil {
				return err
			}
			edges, err := s.repo.LoadBlocksEdges(ctx, tx, pc.ProjectID)
			if err != nil {
				return err
			}
			if HasPath(edges, to.ID, from.ID) {
				return ErrLinkCycle
			}
		}
		if err := s.repo.InsertLink(ctx, tx, pc.ProjectID, from.ID, to.ID, req.Kind, pc.UserID); err != nil {
			if db.IsUniqueViolation(err) {
				return ErrConflict
			}
			return fmt.Errorf("workspace: create link: %w", err)
		}
		actor := pc.UserID
		if err := s.repo.InsertItemEvent(ctx, tx, eventInsert{
			ProjectID: pc.ProjectID, ItemID: from.ID, ActorID: &actor, Source: SourceUser, Kind: EventLink, ToValue: strPtr(req.Kind),
		}); err != nil {
			return err
		}

		if isDuplicate {
			reason := "Duplicate of " + to.Key
			if _, err := s.transitionTx(ctx, tx, transitionInput{
				PC: pc, ItemID: from.ID, Source: SourceSystem, To: ItemWontDo, Reason: &reason, SkipRoleCheck: true,
			}); err != nil {
				return err
			}
		}

		link = &ItemLink{Kind: req.Kind, Direction: "outgoing", Other: ItemRef{ID: to.ID, Key: to.Key, Type: to.Type, Title: to.Title, Status: to.Status}, CreatedBy: &pc.UserID, CreatedAt: s.now()}
		return nil
	})
	if err != nil {
		return nil, err
	}

	if isDuplicate {
		s.notifyDuplicateClosed(ctx, pc.OrgID, from, to)
	}
	return link, nil
}

// notifyDuplicateClosed notifies the closed item's assignees and reporter
// after commit (contract-phase2.md "duplicates" — best-effort, never fails
// the request that triggered it).
func (s *Service) notifyDuplicateClosed(ctx context.Context, orgID string, item, original *WorkItem) {
	assignees, err := s.repo.ListAssigneesByItem(ctx, s.pool, item.ID)
	if err != nil {
		slog.ErrorContext(ctx, "workspace: notify duplicate closed: list assignees", "error", err)
		return
	}
	recipients := map[string]bool{}
	for _, a := range assignees {
		recipients[a.UserID] = true
	}
	if item.CreatedBy != nil {
		recipients[*item.CreatedBy] = true
	}
	if len(recipients) == 0 {
		return
	}
	ids := make([]string, 0, len(recipients))
	for id := range recipients {
		ids = append(ids, id)
	}
	body := fmt.Sprintf("%s was closed as a duplicate of %s.", item.Key, original.Key)
	err = s.repo.InTx(ctx, func(tx pgx.Tx) error {
		return s.notif.NotifyMany(ctx, tx, notifications.New{
			OrgID: orgID, Type: "workspace_item_duplicate", Title: "Item closed as duplicate", Body: &body,
			EntityType: strPtr("work_item"), EntityID: &item.ID, DedupeKey: "workspace_item_duplicate:" + item.ID,
		}, ids)
	})
	if err != nil {
		slog.ErrorContext(ctx, "workspace: notify duplicate closed", "error", err)
	}
}

// DeleteLink removes one link edge (contract-phase2.md "Links").
func (s *Service) DeleteLink(ctx context.Context, pc *ProjectCtx, itemID, toItemID, kind string) error {
	if !contains(linkKinds, kind) {
		return fmt.Errorf("%w: unknown link kind %q", ErrInvalidInput, kind)
	}
	if err := s.repo.DeleteLink(ctx, s.pool, pc.ProjectID, itemID, toItemID, kind); err != nil {
		return err
	}
	actor := pc.UserID
	return s.repo.InsertItemEvent(ctx, s.pool, eventInsert{
		ProjectID: pc.ProjectID, ItemID: itemID, ActorID: &actor, Source: SourceUser, Kind: EventUnlink, FromValue: strPtr(kind),
	})
}
