package calendar

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/mindforge/backend/internal/authz"
)

// ErrInvalid signals a request that failed validation before reaching the database.
var ErrInvalid = errors.New("calendar: invalid input")

// ErrForbidden is returned when the caller may see an event (or isn't even
// allowed that much) but may not perform the requested mutation on it.
var ErrForbidden = errors.New("calendar: forbidden")

// PermissionManageEvents lets a role mutate ANY event in the org regardless
// of attendee role — mirrors backend/db/migrations/031_calendar.sql.
const PermissionManageEvents = "calendar.events.manage"

// maxRangeWindow bounds how wide a single ListRange query may span, so an
// unbounded ?from=&to= can't force a full-history scan (or, worse, an
// unbounded-recurrence expansion) on every request.
const maxRangeWindow = 366 * 24 * time.Hour

type Service struct {
	repo     *Repo
	authzSvc *authz.Service
}

func NewService(repo *Repo, authzSvc *authz.Service) *Service {
	return &Service{repo: repo, authzSvc: authzSvc}
}

// normalizeAndValidateEvent defaults an empty Visibility to 'private' and
// validates the result, returning the (possibly-defaulted) Event so the
// caller uses the same value that was actually validated — a value-receiver
// default that the caller then discarded would let an empty Visibility slip
// through to the DB's NOT NULL CHECK constraint instead of being normalized.
func normalizeAndValidateEvent(e Event) (Event, error) {
	if !IsValidEventType(e.EventType) {
		return Event{}, fmt.Errorf("%w: event_type must be one of mentor_session, live_class, deadline, custom, task", ErrInvalid)
	}
	if len(e.Title) < 1 || len(e.Title) > 200 {
		return Event{}, fmt.Errorf("%w: title must be between 1 and 200 characters", ErrInvalid)
	}
	if e.Visibility == "" {
		e.Visibility = VisibilityPrivate
	}
	if !IsValidVisibility(e.Visibility) {
		return Event{}, fmt.Errorf("%w: visibility must be one of private, shared, public", ErrInvalid)
	}
	if e.StartsAt.IsZero() {
		return Event{}, fmt.Errorf("%w: starts_at is required", ErrInvalid)
	}
	if e.EndsAt != nil && !e.EndsAt.After(e.StartsAt) {
		return Event{}, fmt.Errorf("%w: ends_at must be after starts_at", ErrInvalid)
	}
	if e.RecurrenceRule != nil && *e.RecurrenceRule != "" {
		if _, err := ParseRRule(*e.RecurrenceRule); err != nil {
			return Event{}, fmt.Errorf("%w: %v", ErrInvalid, err)
		}
	}
	return e, nil
}

// CreateEvent validates and creates a new event. The creator is always
// inserted as its 'owner' attendee; any additional attendeeUserIDs are added
// as 'viewer'. Both inserts happen in the same transaction as the event row.
//
// No jobs.Enqueue call is made here: the reminder job (see
// jobs/handlers/calendar_reminder.go) is a periodic sweep over
// calendar_events.status='scheduled' by starts_at window, matching every
// other time-based notification in this codebase (srs.go, mentor_escalation.go,
// assessment expiry) — a new event is simply picked up on its own by the next
// tick, with no per-write scheduling call needed.
func (s *Service) CreateEvent(ctx context.Context, e Event, attendeeUserIDs []string) (Event, error) {
	e, err := normalizeAndValidateEvent(e)
	if err != nil {
		return Event{}, err
	}

	var created Event
	err = s.repo.tx(ctx, func(tx pgx.Tx) error {
		var txErr error
		created, txErr = s.repo.CreateTx(ctx, tx, e)
		if txErr != nil {
			return txErr
		}
		if txErr = s.repo.AddAttendeeTx(ctx, tx, created.ID, created.CreatedBy, AttendeeRoleOwner); txErr != nil {
			return txErr
		}
		for _, uid := range attendeeUserIDs {
			if uid == "" || uid == created.CreatedBy {
				continue
			}
			if txErr = s.repo.AddAttendeeTx(ctx, tx, created.ID, uid, AttendeeRoleViewer); txErr != nil {
				return txErr
			}
		}
		return nil
	})
	if err != nil {
		return Event{}, err
	}
	return created, nil
}

// GetEvent returns an event, its attendees, and its still-pending external
// invites, scoped to orgID, if callerID may view it.
func (s *Service) GetEvent(ctx context.Context, orgID, eventID, callerID string) (Event, []Attendee, []EventInvite, error) {
	event, err := s.repo.GetByID(ctx, orgID, eventID)
	if err != nil {
		return Event{}, nil, nil, err
	}
	canView, err := s.canView(ctx, orgID, eventID, callerID)
	if err != nil {
		return Event{}, nil, nil, err
	}
	if !canView {
		return Event{}, nil, nil, ErrForbidden
	}
	attendees, err := s.repo.GetAttendees(ctx, eventID)
	if err != nil {
		return Event{}, nil, nil, err
	}
	pendingInvites, err := s.repo.ListPendingInvitesByEvent(ctx, eventID)
	if err != nil {
		return Event{}, nil, nil, err
	}
	return event, attendees, pendingInvites, nil
}

// ListRange returns every event (real, expanded from recurrence, and virtual
// assessment windows) callerID may see in orgID between from and to.
func (s *Service) ListRange(ctx context.Context, orgID, callerID string, from, to time.Time) ([]Event, error) {
	if !to.After(from) {
		return nil, fmt.Errorf("%w: to must be after from", ErrInvalid)
	}
	if to.Sub(from) > maxRangeWindow {
		return nil, fmt.Errorf("%w: date range cannot exceed %d days", ErrInvalid, int(maxRangeWindow.Hours()/24))
	}
	return s.repo.ListRange(ctx, orgID, callerID, from, to)
}

// canView reports whether callerID may view eventID — an org-wide
// calendar.events.manage permission also grants view access, matching how it
// grants mutate access.
func (s *Service) canView(ctx context.Context, orgID, eventID, callerID string) (bool, error) {
	ok, err := s.repo.CanAccessEvent(ctx, orgID, eventID, callerID)
	if err != nil {
		return false, err
	}
	if ok {
		return true, nil
	}
	return s.authzSvc.HasPermission(ctx, callerID, orgID, PermissionManageEvents)
}

// canMutate reports whether callerID may edit/delete/invite-on eventID: they
// hold the 'owner' or 'editor' attendee role, or they hold
// calendar.events.manage in orgID.
func (s *Service) canMutate(ctx context.Context, orgID, eventID, callerID string) (bool, error) {
	role, ok, err := s.repo.GetAttendeeRole(ctx, eventID, callerID)
	if err != nil {
		return false, err
	}
	if ok && (role == AttendeeRoleOwner || role == AttendeeRoleEditor) {
		return true, nil
	}
	return s.authzSvc.HasPermission(ctx, callerID, orgID, PermissionManageEvents)
}

// UpdateEvent applies patch (the caller's fully-resolved desired state — see
// Handler.UpdateEvent, which merges the incoming partial JSON body onto the
// current row before calling this) to eventID.
//
// scope only matters when the target is a recurring master
// (RecurrenceRule set, RecurrenceParentID nil): ScopeSeries edits the master
// row directly (every future occurrence changes); ScopeSingle requires
// occurrenceStartsAt (which occurrence is being edited) and instead creates a
// standalone detached copy — recurrence_parent_id pointing at the master,
// recurrence_rule cleared, attendees copied — and excludes that occurrence
// from the master's own expansion. An event that is already a detached
// single occurrence (RecurrenceParentID set) or has no recurrence at all is
// always edited in place regardless of scope.
func (s *Service) UpdateEvent(ctx context.Context, orgID, eventID, callerID, scope string, occurrenceStartsAt *time.Time, patch Event) (Event, error) {
	patch, err := normalizeAndValidateEvent(patch)
	if err != nil {
		return Event{}, err
	}
	base, err := s.repo.GetByID(ctx, orgID, eventID)
	if err != nil {
		return Event{}, err
	}
	allowed, err := s.canMutate(ctx, orgID, eventID, callerID)
	if err != nil {
		return Event{}, err
	}
	if !allowed {
		return Event{}, ErrForbidden
	}

	isMaster := base.RecurrenceParentID == nil && base.RecurrenceRule != nil && *base.RecurrenceRule != ""
	if isMaster && scope == ScopeSingle {
		if occurrenceStartsAt == nil {
			return Event{}, fmt.Errorf("%w: occurrence_starts_at is required when scope=single on a recurring event", ErrInvalid)
		}
		return s.detachOccurrence(ctx, orgID, base, *occurrenceStartsAt, patch)
	}

	patch.ID = base.ID
	updated, err := s.repo.Update(ctx, orgID, patch)
	if err != nil {
		return Event{}, err
	}
	return updated, nil
}

// detachOccurrence creates a standalone copy of one occurrence of a
// recurring master, carries over its attendee list, and marks the occurrence
// excluded from the master's own expansion — all in one transaction.
func (s *Service) detachOccurrence(ctx context.Context, orgID string, base Event, occurrenceStartsAt time.Time, patch Event) (Event, error) {
	var detached Event
	err := s.repo.tx(ctx, func(tx pgx.Tx) error {
		detachedRow := Event{
			OrgID:              orgID,
			CreatedBy:          base.CreatedBy,
			EventType:          patch.EventType,
			Title:              patch.Title,
			Notes:              patch.Notes,
			MeetingURL:         patch.MeetingURL,
			StartsAt:           patch.StartsAt,
			EndsAt:             patch.EndsAt,
			AllDay:             patch.AllDay,
			Visibility:         patch.Visibility,
			BatchID:            patch.BatchID,
			CourseID:           patch.CourseID,
			EntityType:         patch.EntityType,
			EntityID:           patch.EntityID,
			RecurrenceParentID: &base.ID,
		}
		var txErr error
		detached, txErr = s.repo.CreateDetachedTx(ctx, tx, detachedRow)
		if txErr != nil {
			return txErr
		}

		attendees, txErr := s.repo.ListAttendeeUserIDsTx(ctx, tx, base.ID)
		if txErr != nil {
			return txErr
		}
		for _, a := range attendees {
			if txErr = s.repo.AddAttendeeTx(ctx, tx, detached.ID, a.UserID, a.Role); txErr != nil {
				return txErr
			}
		}

		return s.repo.AddExcludedOccurrenceTx(ctx, tx, orgID, base.ID, occurrenceStartsAt)
	})
	if err != nil {
		return Event{}, err
	}
	return detached, nil
}

// UpdateNotes overwrites only an event's notes field — the lightweight path
// for the collaborative "plan" content, separate from the full UpdateEvent
// so an editor jotting notes doesn't need to resend the entire event.
func (s *Service) UpdateNotes(ctx context.Context, orgID, eventID, callerID string, notes *string) (Event, error) {
	allowed, err := s.canMutate(ctx, orgID, eventID, callerID)
	if err != nil {
		return Event{}, err
	}
	if !allowed {
		return Event{}, ErrForbidden
	}
	return s.repo.UpdateNotes(ctx, orgID, eventID, notes)
}

// SetCompleted checks or unchecks a task event. Meaningful only on
// EventTypeTask rows, but not restricted to them at this layer — the same
// checkbox toggle a caller might reuse for a deadline they want to track.
func (s *Service) SetCompleted(ctx context.Context, orgID, eventID, callerID string, completed bool) (Event, error) {
	allowed, err := s.canMutate(ctx, orgID, eventID, callerID)
	if err != nil {
		return Event{}, err
	}
	if !allowed {
		return Event{}, ErrForbidden
	}
	return s.repo.SetCompleted(ctx, orgID, eventID, completed)
}

// DeleteEvent cancels eventID. scope/occurrenceStartsAt follow the same
// rules as UpdateEvent, except a single-occurrence delete never creates a
// detached row — it only records the occurrence as excluded, removing it
// from the master's expansion.
func (s *Service) DeleteEvent(ctx context.Context, orgID, eventID, callerID, scope string, occurrenceStartsAt *time.Time) error {
	base, err := s.repo.GetByID(ctx, orgID, eventID)
	if err != nil {
		return err
	}
	allowed, err := s.canMutate(ctx, orgID, eventID, callerID)
	if err != nil {
		return err
	}
	if !allowed {
		return ErrForbidden
	}

	isMaster := base.RecurrenceParentID == nil && base.RecurrenceRule != nil && *base.RecurrenceRule != ""
	if isMaster && scope == ScopeSingle {
		if occurrenceStartsAt == nil {
			return fmt.Errorf("%w: occurrence_starts_at is required when scope=single on a recurring event", ErrInvalid)
		}
		return s.repo.tx(ctx, func(tx pgx.Tx) error {
			return s.repo.AddExcludedOccurrenceTx(ctx, tx, orgID, base.ID, *occurrenceStartsAt)
		})
	}

	_, err = s.repo.Cancel(ctx, orgID, eventID)
	return err
}

// RSVP sets the caller's own rsvp_status on eventID. Any attendee (owner,
// editor, or viewer) may change their own RSVP; the UPDATE is scoped to
// (event_id, user_id) so it can never touch another attendee's row.
func (s *Service) RSVP(ctx context.Context, eventID, callerID, status string) (Attendee, error) {
	if !IsValidRSVPStatus(status) {
		return Attendee{}, fmt.Errorf("%w: rsvp_status must be one of pending, accepted, declined", ErrInvalid)
	}
	attendee, err := s.repo.UpdateRSVP(ctx, eventID, callerID, status)
	if err != nil {
		return Attendee{}, err
	}
	return attendee, nil
}

// ErrFeedTokenExists is returned by GetOrCreateFeedURL when callerID already
// has a feed token and rotate=false. Only the hash is stored (by design — a
// DB leak must not hand out usable feed URLs), so the raw token cannot be
// re-displayed after the mint that created it; silently minting a fresh one
// on every call instead would rotate — and break — every external calendar
// subscription each time the user revisits the settings page. The caller
// must explicitly ask to rotate.
var ErrFeedTokenExists = errors.New("calendar: feed token already issued")

// GetOrCreateFeedURL returns callerID's personal ICS feed URL for orgID. On
// first call it mints a token and returns the URL. On a later call, unless
// rotate is true, it returns ErrFeedTokenExists without changing anything —
// see that error's doc comment for why. rotate=true always mints a fresh
// token, invalidating any URL handed out previously.
func (s *Service) GetOrCreateFeedURL(ctx context.Context, backendURL, orgID, callerID string, rotate bool) (string, error) {
	_, exists, err := s.repo.GetFeedTokenHash(ctx, callerID, orgID)
	if err != nil {
		return "", err
	}
	if exists && !rotate {
		return "", ErrFeedTokenExists
	}

	rawToken, hash, err := newFeedToken(callerID, orgID)
	if err != nil {
		return "", fmt.Errorf("calendar: generate feed token: %w", err)
	}
	if err := s.repo.UpsertFeedTokenHash(ctx, callerID, orgID, hash); err != nil {
		return "", err
	}
	return backendURL + "/api/calendar/events.ics?token=" + rawToken, nil
}

// VerifyFeedToken resolves a raw feed token from a GET /events.ics?token=
// request into the (userID, orgID) that own it.
func (s *Service) VerifyFeedToken(ctx context.Context, rawToken string) (userID, orgID string, err error) {
	hash := hashToken(rawToken)
	return s.repo.ResolveFeedTokenHash(ctx, hash)
}
