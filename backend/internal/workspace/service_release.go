package workspace

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/db"
)

// service_release.go — Phase 5 (contract-phase5.md 5a): release CRUD and the
// planned→frozen→released lifecycle.

// ListReleases is GET …/releases (viewer, no status gate).
func (s *Service) ListReleases(ctx context.Context, pc *ProjectCtx) ([]Release, error) {
	return s.repo.ListReleases(ctx, s.pool, pc.ProjectID)
}

// CreateRelease is POST …/releases (manager+, StatusesPlanning).
func (s *Service) CreateRelease(ctx context.Context, pc *ProjectCtx, req CreateReleaseRequest) (*Release, error) {
	version := strings.TrimSpace(req.Version)
	if len(version) < 1 || len(version) > ReleaseVersionMaxLen {
		return nil, &FieldError{Fields: map[string]string{"version": fmt.Sprintf("Version must be 1-%d characters.", ReleaseVersionMaxLen)}}
	}

	var rel *Release
	err := s.repo.InTx(ctx, func(tx pgx.Tx) error {
		taken, err := s.repo.ReleaseVersionTaken(ctx, tx, pc.ProjectID, version, "")
		if err != nil {
			return err
		}
		if taken {
			return ErrConflict
		}
		r, err := s.repo.InsertRelease(ctx, tx, pc.ProjectID, version, req.TargetAt, pc.UserID)
		if err != nil {
			if db.IsUniqueViolation(err) {
				return ErrConflict
			}
			return fmt.Errorf("workspace: create release: %w", err)
		}
		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_release.created", "release", r.ID, map[string]string{"version": version})
		rel = r
		return nil
	})
	if err != nil {
		return nil, err
	}
	return s.repo.GetRelease(ctx, s.pool, pc.ProjectID, rel.ID)
}

// UpdateRelease is PATCH …/releases/{releaseID} (manager+, StatusesPlanning):
// version/target_at edits and the planned→frozen→released lifecycle, all
// under the release row's own FOR UPDATE lock.
func (s *Service) UpdateRelease(ctx context.Context, pc *ProjectCtx, releaseID string, req UpdateReleaseRequest) (*Release, error) {
	err := s.repo.InTx(ctx, func(tx pgx.Tx) error {
		current, err := s.repo.LockRelease(ctx, tx, pc.ProjectID, releaseID)
		if err != nil {
			return err
		}

		version := current.Version
		if req.Version != nil {
			v := strings.TrimSpace(*req.Version)
			if len(v) < 1 || len(v) > ReleaseVersionMaxLen {
				return &FieldError{Fields: map[string]string{"version": fmt.Sprintf("Version must be 1-%d characters.", ReleaseVersionMaxLen)}}
			}
			version = v
		}
		if version != current.Version {
			taken, err := s.repo.ReleaseVersionTaken(ctx, tx, pc.ProjectID, version, releaseID)
			if err != nil {
				return err
			}
			if taken {
				return ErrConflict
			}
		}
		targetAt := current.TargetAt
		if req.ClearTarget {
			targetAt = nil
		} else if req.TargetAt != nil {
			targetAt = req.TargetAt
		}
		if _, err := s.repo.UpdateReleaseFields(ctx, tx, pc.ProjectID, releaseID, version, targetAt, req.ClearTarget); err != nil {
			if db.IsUniqueViolation(err) {
				return ErrConflict
			}
			return fmt.Errorf("workspace: update release: %w", err)
		}

		if req.Status != nil && *req.Status != current.Status {
			to := *req.Status
			if !ReleaseStatusMachine.Allowed(current.Status, to) {
				return ErrIllegalTransition
			}
			if to == ReleaseReleased {
				notDone, err := s.repo.CountFeaturesNotDoneInRelease(ctx, tx, releaseID)
				if err != nil {
					return err
				}
				if notDone > 0 {
					return ErrReleaseNotReady
				}
				items, err := s.repo.ListItemsByRelease(ctx, tx, pc.ProjectID, releaseID)
				if err != nil {
					return err
				}
				for _, it := range items {
					if err := s.repo.InsertReleaseSnapshot(ctx, tx, releaseID, it.ID, it.ApprovedDocVersion, it.Status); err != nil {
						return err
					}
				}
			}
			if _, err := s.repo.UpdateReleaseStatus(ctx, tx, pc.ProjectID, releaseID, to); err != nil {
				return fmt.Errorf("workspace: update release status: %w", err)
			}
			writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_release.status_changed", "release", releaseID,
				map[string]string{"from": current.Status, "to": to})
		} else {
			writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_release.updated", "release", releaseID, nil)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return s.repo.GetRelease(ctx, s.pool, pc.ProjectID, releaseID)
}

// SetItemRelease is PUT …/items/{itemID}/release (route min member; the
// service applies the same editor rule UpdateWorkItem uses — creator, any
// assignee, manager+, or the item's track lead). A frozen target release only
// accepts bugs (hotfix pattern); any other type gets ErrReleaseFrozen.
func (s *Service) SetItemRelease(ctx context.Context, pc *ProjectCtx, itemID string, req SetItemReleaseRequest) (*WorkItem, error) {
	current, err := s.repo.GetWorkItemByID(ctx, s.pool, pc.ProjectID, itemID)
	if err != nil {
		return nil, err
	}
	current.Assignees, err = s.repo.ListAssigneesByItem(ctx, s.pool, current.ID)
	if err != nil {
		return nil, err
	}
	// contract-phase5.md's route table: route min is member, but a feature's
	// release is manager+/track-lead only (release planning is a leadership
	// call); any other item type follows the ordinary editor rule
	// (UpdateWorkItem's own creator/assignee/manager+/track-lead check).
	if current.Type == ItemTypeFeature {
		if !RoleAtLeast(pc.Role, RoleManager) {
			lead := false
			if current.TrackID != nil {
				lead, err = s.repo.IsTrackLead(ctx, s.pool, pc.ProjectID, *current.TrackID, pc.UserID)
				if err != nil {
					return nil, err
				}
			}
			if !lead {
				return nil, ErrForbidden
			}
		}
	} else {
		canEdit, err := s.canEditItem(ctx, s.pool, pc, current)
		if err != nil {
			return nil, err
		}
		if !canEdit {
			return nil, ErrForbidden
		}
	}

	if req.ReleaseID != nil {
		release, err := s.repo.GetRelease(ctx, s.pool, pc.ProjectID, *req.ReleaseID)
		if err != nil {
			return nil, err
		}
		if release.Status == ReleaseFrozen && current.Type != ItemTypeBug {
			return nil, ErrReleaseFrozen
		}
	}

	var updated *WorkItem
	err = s.repo.InTx(ctx, func(tx pgx.Tx) error {
		u, err := s.repo.SetItemRelease(ctx, tx, pc.ProjectID, itemID, req.Version, req.ReleaseID)
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
			ProjectID: pc.ProjectID, ItemID: itemID, ActorID: &actor, Source: SourceUser, Kind: EventRelease,
			FromValue: current.ReleaseID, ToValue: req.ReleaseID,
		}); err != nil {
			return err
		}
		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_item.release_set", "work_item", itemID, nil)
		updated = u
		return nil
	})
	if err != nil {
		return nil, err
	}
	return updated, nil
}

// releaseNotesCacheKind is workspace_ai_cache's kind for GetReleaseNotes'
// polished text — cached forever per release (a released version's shipped
// set never changes), matching the "AI called once" convention.
const releaseNotesCacheKind = "release_notes"

type releaseNotesCached struct {
	Notes string `json:"notes"`
}

// GetReleaseNotes is GET …/releases/{releaseID}/notes?polish= (viewer;
// polish requires manager+). Items come from release_snapshots once
// released, or live from work_items before that.
func (s *Service) GetReleaseNotes(ctx context.Context, pc *ProjectCtx, releaseID string, polish bool) (*ReleaseNotes, error) {
	release, err := s.repo.GetRelease(ctx, s.pool, pc.ProjectID, releaseID)
	if err != nil {
		return nil, err
	}
	if polish && !RoleAtLeast(pc.Role, RoleManager) {
		return nil, ErrForbidden
	}

	var items []ReleaseNoteItem
	if release.Status == ReleaseReleased {
		items, err = s.repo.ListReleaseSnapshotItems(ctx, s.pool, pc.ProjectID, releaseID)
	} else {
		var live []WorkItem
		live, err = s.repo.ListItemsByRelease(ctx, s.pool, pc.ProjectID, releaseID)
		items = make([]ReleaseNoteItem, len(live))
		for i, it := range live {
			items[i] = ReleaseNoteItem{
				Item:       ItemRef{ID: it.ID, Key: it.Key, Type: it.Type, Title: it.Title, Status: it.Status},
				DocVersion: it.ApprovedDocVersion,
			}
		}
	}
	if err != nil {
		return nil, err
	}
	notes := &ReleaseNotes{ReleaseID: releaseID, Items: items}
	if !polish {
		return notes, nil
	}

	cacheKey := "release:" + releaseID
	var cached releaseNotesCached
	if found, err := s.repo.GetAICache(ctx, s.pool, pc.ProjectID, releaseNotesCacheKind, cacheKey, &cached); err != nil {
		return nil, err
	} else if found {
		notes.Polished = &cached.Notes
		return notes, nil
	}

	if s.ai == nil || !s.ai.Available() {
		return nil, fmt.Errorf("%w: AI is not configured", ErrInvalidState)
	}
	if allowed, retryAfter := s.limiter.Allow(ctx, "rl:pw:summary:"+pc.ProjectID, s.cfg.Workspace.SummaryRegenPerDay, 24*time.Hour); !allowed {
		return nil, &RateLimitError{RetryAfter: retryAfter}
	}

	var b strings.Builder
	fmt.Fprintf(&b, "Release version: %s\n\nShipped items:\n", delimited(release.Version))
	for _, it := range items {
		fmt.Fprintf(&b, "- [%s] %s\n", it.Item.Type, delimited(it.Item.Title))
	}

	resp, err := s.ai.Complete(ctx, ai.CompletionRequest{
		SystemPrompt: ai.WorkspaceReleaseNotesPolishSystemPrompt,
		UserPrompt:   b.String(),
		MaxTokens:    600,
		Temperature:  0.3,
		JSONMode:     true,
	})
	if err != nil {
		return nil, fmt.Errorf("workspace: release notes polish: %w", err)
	}
	var parsed releaseNotesCached
	if err := json.Unmarshal([]byte(resp.Content), &parsed); err != nil {
		return nil, fmt.Errorf("workspace: release notes polish: parse response: %w", err)
	}
	if err := s.repo.SetAICache(ctx, s.pool, pc.ProjectID, releaseNotesCacheKind, cacheKey, parsed); err != nil {
		return nil, err
	}
	writeAudit(ctx, s.pool, pc.OrgID, &pc.UserID, "workspace_release.notes_polished", "release", releaseID, nil)
	notes.Polished = &parsed.Notes
	return notes, nil
}
