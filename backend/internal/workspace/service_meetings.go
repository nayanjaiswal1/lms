package workspace

import (
	"context"
	"encoding/json"
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/mindforge/backend/internal/calendar"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/pagination"
	"github.com/mindforge/backend/internal/wiki"
)

// service_meetings.go — meetings, attendance, action items and async
// standups (contract-phase3.md "Meetings" / "Standups"). Scheduling a
// meeting is two commits, not one: calendar.Service.CreateEvent runs its own
// transaction (see that method's doc comment — every other domain that
// creates a calendar event lives with the same split), so a workspace tx
// failure after the event exists leaves an orphaned but harmless calendar
// event rather than corrupting either side.

var meetingNotesTitles = map[string]string{
	"kickoff":         "Kickoff Notes",
	"sprint_planning": "Sprint Planning Notes",
	"standup":         "Standup Notes",
	"design_review":   "Design Review Notes",
	"retro":           "Retro Notes",
	"demo":            "Demo Notes",
}

// meetingNotesTemplate seeds the meeting's notes page in code (contract-
// phase3.md: "notes wiki page per kind template (seeded in code)").
func meetingNotesTemplate(kind string) (title string, content json.RawMessage) {
	title = meetingNotesTitles[kind]
	doc := map[string]any{"type": "doc", "content": []map[string]any{
		{"type": "heading", "attrs": map[string]any{"level": 2}, "content": []map[string]any{{"type": "text", "text": "Agenda"}}},
		{"type": "paragraph"},
		{"type": "heading", "attrs": map[string]any{"level": 2}, "content": []map[string]any{{"type": "text", "text": "Notes"}}},
		{"type": "paragraph"},
		{"type": "heading", "attrs": map[string]any{"level": 2}, "content": []map[string]any{{"type": "text", "text": "Action Items"}}},
		{"type": "paragraph"},
	}}
	raw, _ := json.Marshal(doc)
	return title, raw
}

// ListMeetings cursor-paginates a project's meetings, newest-scheduled first.
func (s *Service) ListMeetings(ctx context.Context, pc *ProjectCtx, cursor string, limit int) (Page[Meeting], error) {
	limit = clampLimit(limit)
	cursorAt, cursorID, err := pagination.DecodeCursor(cursor, "workspace_meetings")
	if err != nil {
		cursorAt, cursorID = time.Time{}, ""
	}
	items, err := s.repo.ListMeetings(ctx, s.pool, pc.ProjectID, cursorAt, cursorID, limit+1)
	if err != nil {
		return Page[Meeting]{}, err
	}
	page := Page[Meeting]{Items: items}
	if len(items) > limit {
		page.Items = items[:limit]
		last := page.Items[limit-1]
		page.NextCursor = pagination.EncodeCursor(last.CreatedAt, last.CalendarEventID)
	}
	return page, nil
}

// ScheduleMeeting is manager+ scheduling any meeting kind.
func (s *Service) ScheduleMeeting(ctx context.Context, pc *ProjectCtx, req ScheduleMeetingRequest) (*Meeting, error) {
	if !RoleAtLeast(pc.Role, RoleManager) {
		return nil, ErrForbidden
	}
	return s.scheduleMeetingTx(ctx, pc, req)
}

// scheduleMeetingTx is the shared core behind ScheduleMeeting and
// ScheduleDesignReview (service_doc.go) — the caller has already checked who
// may schedule; this only validates the request and does the two-commit
// create.
func (s *Service) scheduleMeetingTx(ctx context.Context, pc *ProjectCtx, req ScheduleMeetingRequest) (*Meeting, error) {
	if !contains(MeetingKinds, req.Kind) {
		return nil, fmt.Errorf("%w: kind must be one of %s", ErrInvalidInput, strings.Join(MeetingKinds, ", "))
	}
	title := strings.TrimSpace(req.Title)
	if title == "" || len(title) > TitleMaxLen {
		return nil, &FieldError{Fields: map[string]string{"title": fmt.Sprintf("Title must be 1-%d characters.", TitleMaxLen)}}
	}
	if req.StartsAt.IsZero() {
		return nil, fmt.Errorf("%w: starts_at is required", ErrInvalidInput)
	}
	if s.calendar == nil {
		return nil, fmt.Errorf("%w: calendar is not configured", ErrInvalidState)
	}

	activeAttendees := make([]string, 0, len(req.AttendeeIDs))
	for _, uid := range req.AttendeeIDs {
		if uid == pc.UserID {
			continue
		}
		member, err := s.repo.GetMember(ctx, s.pool, pc.ProjectID, uid)
		if err != nil || member.Status != MemberActive {
			continue
		}
		activeAttendees = append(activeAttendees, uid)
	}

	event, err := s.calendar.CreateEvent(ctx, calendar.Event{
		OrgID: pc.OrgID, CreatedBy: pc.UserID, EventType: calendar.EventTypeCustom, Title: title,
		StartsAt: req.StartsAt, EndsAt: req.EndsAt, Visibility: calendar.VisibilityShared,
		EntityType: strPtr("workspace_project"), EntityID: &pc.ProjectID,
		RecurrenceRule: req.RecurrenceRule, MeetingURL: req.MeetingURL,
	}, activeAttendees)
	if err != nil {
		return nil, fmt.Errorf("workspace: schedule meeting: create event: %w", err)
	}

	err = s.repo.InTx(ctx, func(tx pgx.Tx) error {
		spaceID, _, err := s.repo.GetProjectWikiSpace(ctx, tx, pc.ProjectID)
		if err != nil {
			return err
		}
		var notesPageID *string
		if spaceID != nil {
			notesTitle, content := meetingNotesTemplate(req.Kind)
			slug := courses.Slugify(notesTitle) + "-" + event.ID[:8]
			page, err := wiki.CreatePageTx(ctx, tx, *spaceID, notesTitle, slug, nil, nil, content, "", pc.UserID)
			if err != nil {
				return fmt.Errorf("workspace: schedule meeting: create notes page: %w", err)
			}
			notesPageID = &page.ID
		}
		if err := s.repo.InsertMeeting(ctx, tx, event.ID, pc.ProjectID, req.Kind, req.ItemID, notesPageID, pc.UserID); err != nil {
			return err
		}
		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_meeting.scheduled", "calendar_event", event.ID, map[string]string{"kind": req.Kind})
		return nil
	})
	if err != nil {
		return nil, err
	}
	return s.repo.GetMeeting(ctx, s.pool, pc.ProjectID, event.ID)
}

// RecordAttendance is manager+ marking attendance for one occurrence.
func (s *Service) RecordAttendance(ctx context.Context, pc *ProjectCtx, eventID string, req RecordAttendanceRequest) error {
	if _, err := s.repo.GetMeeting(ctx, s.pool, pc.ProjectID, eventID); err != nil {
		return err
	}
	if req.OccurrenceAt.IsZero() {
		return fmt.Errorf("%w: occurrence_at is required", ErrInvalidInput)
	}
	for _, e := range req.Entries {
		if e.Status != "attended" && e.Status != "missed" {
			return fmt.Errorf("%w: status must be attended or missed", ErrInvalidInput)
		}
		member, err := s.repo.GetMember(ctx, s.pool, pc.ProjectID, e.UserID)
		if err != nil {
			return err
		}
		if member.Status != MemberActive {
			return fmt.Errorf("%w: %s is not an active project member", ErrInvalidInput, member.Name)
		}
	}
	return s.repo.InTx(ctx, func(tx pgx.Tx) error {
		for _, e := range req.Entries {
			if err := s.repo.UpsertAttendance(ctx, tx, eventID, req.OccurrenceAt, e.UserID, e.Status, pc.UserID); err != nil {
				return err
			}
		}
		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_meeting.attendance_recorded", "calendar_event", eventID, nil)
		return nil
	})
}

// ConvertActionItem turns a meeting action item into a ticket, dup-checked
// against the project's open items first (contract-phase3.md).
func (s *Service) ConvertActionItem(ctx context.Context, pc *ProjectCtx, eventID string, req ActionItemRequest) (*CreateWorkItemResult, error) {
	if _, err := s.repo.GetMeeting(ctx, s.pool, pc.ProjectID, eventID); err != nil {
		return nil, err
	}
	title := strings.TrimSpace(req.Title)
	if title == "" {
		return nil, fmt.Errorf("%w: title is required", ErrInvalidInput)
	}
	if !req.Force {
		var similar []SimilarItem
		err := s.repo.InTx(ctx, func(tx pgx.Tx) error {
			items, err := s.repo.ListSimilarItems(ctx, tx, pc.ProjectID, title, "")
			if err != nil {
				return err
			}
			similar = items
			return nil
		})
		if err != nil {
			return nil, err
		}
		if len(similar) > 0 {
			return &CreateWorkItemResult{Similar: similar}, nil
		}
	}
	return s.CreateWorkItem(ctx, pc, req.CreateWorkItemRequest)
}

// blockerKeyPattern matches ticket-key-shaped tokens in free text
// (contract-phase3.md "Standups"); resolveBlockerKeys keeps only the ones
// matching this project's own key prefix.
var blockerKeyPattern = regexp.MustCompile(`\b([A-Z]{2,6})-(\d{1,9})\b`)

func (s *Service) resolveBlockerKeys(ctx context.Context, pc *ProjectCtx, keyPrefix, text string) []ItemRef {
	out := []ItemRef{}
	if text == "" {
		return out
	}
	for _, m := range blockerKeyPattern.FindAllStringSubmatch(text, -1) {
		if m[1] != keyPrefix {
			continue
		}
		keyNum, err := strconv.Atoi(m[2])
		if err != nil {
			continue
		}
		item, err := s.repo.GetWorkItemByKeyNum(ctx, s.pool, pc.ProjectID, keyNum)
		if err != nil {
			continue
		}
		out = append(out, ItemRef{ID: item.ID, Key: item.Key, Type: item.Type, Title: item.Title, Status: item.Status})
	}
	return out
}

// PostStandup upserts the caller's own standup for today (UTC).
func (s *Service) PostStandup(ctx context.Context, pc *ProjectCtx, req PostStandupRequest) (*Standup, error) {
	yesterday := strings.TrimSpace(req.Yesterday)
	today := strings.TrimSpace(req.Today)
	fields := map[string]string{}
	if len(yesterday) == 0 || len(yesterday) > StandupFieldMaxLen {
		fields["yesterday"] = fmt.Sprintf("Required, up to %d characters.", StandupFieldMaxLen)
	}
	if len(today) == 0 || len(today) > StandupFieldMaxLen {
		fields["today"] = fmt.Sprintf("Required, up to %d characters.", StandupFieldMaxLen)
	}
	var blockers *string
	if req.Blockers != nil {
		b := strings.TrimSpace(*req.Blockers)
		if len(b) > StandupFieldMaxLen {
			fields["blockers"] = fmt.Sprintf("Up to %d characters.", StandupFieldMaxLen)
		} else if b != "" {
			blockers = &b
		}
	}
	if len(fields) > 0 {
		return nil, &FieldError{Fields: fields}
	}

	project, err := s.repo.GetProject(ctx, s.pool, pc.OrgID, pc.ProjectID)
	if err != nil {
		return nil, err
	}
	day := s.now().UTC().Format("2006-01-02")
	standup, err := s.repo.UpsertStandup(ctx, s.pool, pc.ProjectID, pc.UserID, day, yesterday, today, blockers)
	if err != nil {
		return nil, err
	}
	if blockers != nil {
		standup.BlockerKeys = s.resolveBlockerKeys(ctx, pc, project.KeyPrefix, *blockers)
	}
	return standup, nil
}

// ListStandups returns every standup posted for one project+day (default
// today, UTC).
func (s *Service) ListStandups(ctx context.Context, pc *ProjectCtx, day string) ([]Standup, error) {
	if day == "" {
		day = s.now().UTC().Format("2006-01-02")
	} else if _, err := time.Parse("2006-01-02", day); err != nil {
		return nil, fmt.Errorf("%w: day must be YYYY-MM-DD", ErrInvalidInput)
	}
	project, err := s.repo.GetProject(ctx, s.pool, pc.OrgID, pc.ProjectID)
	if err != nil {
		return nil, err
	}
	standups, err := s.repo.ListStandups(ctx, s.pool, pc.ProjectID, day)
	if err != nil {
		return nil, err
	}
	for i := range standups {
		if standups[i].Blockers != nil {
			standups[i].BlockerKeys = s.resolveBlockerKeys(ctx, pc, project.KeyPrefix, *standups[i].Blockers)
		}
	}
	return standups, nil
}
