package workspace

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/mindforge/backend/internal/pagination"
)

// service_timelog.go — Phase 4 (contract-phase4.md 4b): per-person time logs
// against a work item, with a per-person daily cap enforced under an advisory
// lock and a 7-day edit window.

// resolveTimeLogVisibility applies 02 §7.2's rule ("member own only, TL own
// track, manager+ all") to a ListTimeLogs call: returns the effective user
// filter to run the query with, or an error if the caller asked for
// something outside what they may see.
func (s *Service) resolveTimeLogVisibility(ctx context.Context, pc *ProjectCtx, itemID, userID string) (string, error) {
	if RoleAtLeast(pc.Role, RoleManager) {
		return userID, nil
	}
	if userID == "" || userID == pc.UserID {
		return pc.UserID, nil
	}
	// Requesting someone else's rows: only that item's track lead may (their
	// own track's people), and only when itemID scopes the request to a
	// track the caller actually leads.
	if itemID != "" {
		item, err := s.repo.GetWorkItemByID(ctx, s.pool, pc.ProjectID, itemID)
		if err != nil {
			return "", err
		}
		if item.TrackID != nil {
			lead, err := s.repo.IsTrackLead(ctx, s.pool, pc.ProjectID, *item.TrackID, pc.UserID)
			if err != nil {
				return "", err
			}
			if lead {
				return userID, nil
			}
		}
	}
	return "", ErrForbidden
}

// ListTimeLogs is GET …/time-logs?item=&user=&cursor= (viewer route; visibility
// narrows what's actually returned per the rule above).
func (s *Service) ListTimeLogs(ctx context.Context, pc *ProjectCtx, itemID, userID, cursor string, limit int) (Page[TimeLog], error) {
	limit = clampLimit(limit)
	effectiveUserID, err := s.resolveTimeLogVisibility(ctx, pc, itemID, userID)
	if err != nil {
		return Page[TimeLog]{}, err
	}
	cursorAt, cursorID, err := pagination.DecodeCursor(cursor, "workspace_time_logs")
	if err != nil {
		cursorAt, cursorID = time.Time{}, ""
	}
	logs, err := s.repo.ListTimeLogs(ctx, s.pool, pc.ProjectID, itemID, effectiveUserID, pc.UserID, cursorAt, cursorID, limit+1)
	if err != nil {
		return Page[TimeLog]{}, err
	}
	page := Page[TimeLog]{Items: logs}
	if len(logs) > limit {
		page.Items = logs[:limit]
		last := page.Items[limit-1]
		page.NextCursor = pagination.EncodeCursor(last.CreatedAt, last.ID)
	}
	return page, nil
}

// validateTimeLogRequest checks the shared bounds (contract-phase4.md 4b):
// 1-720 minutes, note under TimeLogNoteMaxLen, logged_on a real date that's
// not in the future and not more than 7 days in the past.
func validateTimeLogRequest(req TimeLogRequest, now time.Time) (loggedOn time.Time, fieldErr *FieldError) {
	fields := map[string]string{}
	if req.Minutes < 1 || req.Minutes > TimeLogMaxMinutes {
		fields["minutes"] = fmt.Sprintf("Minutes must be between 1 and %d.", TimeLogMaxMinutes)
	}
	if req.Note != nil && len(*req.Note) > TimeLogNoteMaxLen {
		fields["note"] = fmt.Sprintf("Note must be %d characters or fewer.", TimeLogNoteMaxLen)
	}
	day, err := time.Parse("2006-01-02", req.LoggedOn)
	if err != nil {
		fields["logged_on"] = "Logged date must be a valid date (YYYY-MM-DD)."
	} else {
		today := now.Truncate(24 * time.Hour)
		if day.After(today) {
			fields["logged_on"] = "Logged date can't be in the future."
		} else if day.Before(today.AddDate(0, 0, -7)) {
			fields["logged_on"] = "Logged date can't be more than 7 days in the past."
		}
	}
	if len(fields) > 0 {
		return time.Time{}, &FieldError{Fields: fields}
	}
	return day, nil
}

// LogTime is POST …/items/{itemID}/time-logs (member, StatusesWork): always
// logs against the caller's own name.
func (s *Service) LogTime(ctx context.Context, pc *ProjectCtx, itemID string, req TimeLogRequest) (*TimeLog, error) {
	loggedOn, fieldErr := validateTimeLogRequest(req, s.now())
	if fieldErr != nil {
		return nil, fieldErr
	}
	item, err := s.repo.GetWorkItemByID(ctx, s.pool, pc.ProjectID, itemID)
	if err != nil {
		return nil, err
	}
	day := loggedOn.Format("2006-01-02")

	var result *TimeLog
	err = s.repo.InTx(ctx, func(tx pgx.Tx) error {
		sum, err := s.repo.LockDailyMinutes(ctx, tx, pc.UserID, day, "")
		if err != nil {
			return err
		}
		if sum+req.Minutes > TimeLogDailyCap {
			return ErrTimeLogCap
		}
		t, err := s.repo.InsertTimeLog(ctx, tx, pc.ProjectID, item.ID, pc.UserID, req.Minutes, req.Note, day)
		if err != nil {
			return err
		}
		result = t
		return nil
	})
	if err != nil {
		return nil, err
	}
	writeAudit(ctx, s.pool, pc.OrgID, &pc.UserID, "workspace_time_log.created", "work_item_time_log", result.ID,
		map[string]string{"item_id": item.ID, "minutes": fmt.Sprintf("%d", req.Minutes)})
	return result, nil
}

// UpdateTimeLog is PATCH …/time-logs/{logID} (member, StatusesWork): own log
// only, and only within TimeLogEditWindow of its own creation.
func (s *Service) UpdateTimeLog(ctx context.Context, pc *ProjectCtx, logID string, req TimeLogRequest) (*TimeLog, error) {
	loggedOn, fieldErr := validateTimeLogRequest(req, s.now())
	if fieldErr != nil {
		return nil, fieldErr
	}
	day := loggedOn.Format("2006-01-02")

	var result *TimeLog
	err := s.repo.InTx(ctx, func(tx pgx.Tx) error {
		ownerID, _, _, createdAt, err := s.repo.LockTimeLogRow(ctx, tx, pc.ProjectID, logID)
		if err != nil {
			return err
		}
		if ownerID != pc.UserID {
			return ErrForbidden
		}
		if s.now().Sub(createdAt) > TimeLogEditWindow {
			return ErrTimeLogLocked
		}
		sum, err := s.repo.LockDailyMinutes(ctx, tx, pc.UserID, day, logID)
		if err != nil {
			return err
		}
		if sum+req.Minutes > TimeLogDailyCap {
			return ErrTimeLogCap
		}
		if err := s.repo.UpdateTimeLog(ctx, tx, logID, req.Minutes, req.Note, day); err != nil {
			return err
		}
		t, err := s.repo.GetTimeLog(ctx, tx, logID, pc.UserID)
		if err != nil {
			return err
		}
		result = t
		return nil
	})
	if err != nil {
		return nil, err
	}
	writeAudit(ctx, s.pool, pc.OrgID, &pc.UserID, "workspace_time_log.updated", "work_item_time_log", logID, nil)
	return result, nil
}

// DeleteTimeLog is DELETE …/time-logs/{logID} (member, StatusesWork): own
// log only, same edit window as UpdateTimeLog.
func (s *Service) DeleteTimeLog(ctx context.Context, pc *ProjectCtx, logID string) error {
	err := s.repo.InTx(ctx, func(tx pgx.Tx) error {
		ownerID, _, _, createdAt, err := s.repo.LockTimeLogRow(ctx, tx, pc.ProjectID, logID)
		if err != nil {
			return err
		}
		if ownerID != pc.UserID {
			return ErrForbidden
		}
		if s.now().Sub(createdAt) > TimeLogEditWindow {
			return ErrTimeLogLocked
		}
		return s.repo.DeleteTimeLog(ctx, tx, pc.ProjectID, logID)
	})
	if err != nil {
		return err
	}
	writeAudit(ctx, s.pool, pc.OrgID, &pc.UserID, "workspace_time_log.deleted", "work_item_time_log", logID, nil)
	return nil
}
