package sessions

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/mindforge/backend/internal/calendar"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/payments"
)

// CalendarProjector is the slice of calendar.Service this package needs to
// put a booked session on both parties' calendars (and therefore in their
// ICS feeds). A local interface rather than the concrete *calendar.Service so
// the booking logic can be exercised without standing up the calendar
// package's own dependency graph.
type CalendarProjector interface {
	CreateEvent(ctx context.Context, e calendar.Event, attendeeUserIDs []string) (calendar.Event, error)
	DeleteEvent(ctx context.Context, orgID, eventID, callerID, scope string, occurrenceStartsAt *time.Time) error
	UpdateEvent(ctx context.Context, orgID, eventID, callerID, scope string, occurrenceStartsAt *time.Time, patch calendar.Event) (calendar.Event, error)
}

type Service struct {
	repo        *Repo
	calendar    CalendarProjector
	providers   *payments.Registry
	currency    string
	frontendURL string
}

func NewService(repo *Repo, cal CalendarProjector, providers *payments.Registry, cfg *config.Config) *Service {
	return &Service{
		repo:        repo,
		calendar:    cal,
		providers:   providers,
		currency:    cfg.PaymentsCurrency,
		frontendURL: cfg.FrontendURL,
	}
}

// Repo exposes the repository for the sibling checkout/admin files in this
// package. Not part of the public surface of the domain.
func (s *Service) Repo() *Repo { return s.repo }

// GetConfig returns the org's booking policy.
func (s *Service) GetConfig(ctx context.Context, orgID string) (Config, error) {
	return s.repo.GetConfig(ctx, orgID)
}

// UpdateConfig validates and writes the org's booking policy. The bounds
// mirror the CHECK constraints so an out-of-range value comes back as a
// readable 422 rather than a constraint violation.
func (s *Service) UpdateConfig(ctx context.Context, c Config) (Config, error) {
	switch {
	case c.CancelCutoffHours < 0 || c.CancelCutoffHours > 336:
		return Config{}, fmt.Errorf("%w: cancellation cutoff must be between 0 and 336 hours", ErrInvalid)
	case c.MinNoticeHours < 0 || c.MinNoticeHours > 336:
		return Config{}, fmt.Errorf("%w: minimum notice must be between 0 and 336 hours", ErrInvalid)
	case c.BookingHorizonDays < 1 || c.BookingHorizonDays > 365:
		return Config{}, fmt.Errorf("%w: booking horizon must be between 1 and 365 days", ErrInvalid)
	case c.MaxUpcomingPerStudent < 1 || c.MaxUpcomingPerStudent > 100:
		return Config{}, fmt.Errorf("%w: the upcoming-session limit must be between 1 and 100", ErrInvalid)
	case c.DefaultDuration < 5 || c.DefaultDuration > 480:
		return Config{}, fmt.Errorf("%w: default duration must be between 5 and 480 minutes", ErrInvalid)
	}
	return s.repo.UpsertConfig(ctx, c)
}

// ─── availability ──────────────────────────────────────────────────────────

// ListAvailability returns a mentor's own weekly rules plus their upcoming
// one-off overrides.
func (s *Service) ListAvailability(ctx context.Context, orgID, mentorID string) ([]AvailabilityRule, []AvailabilityException, error) {
	rules, err := s.repo.ListRules(ctx, orgID, mentorID)
	if err != nil {
		return nil, nil, err
	}
	now := time.Now()
	exceptions, err := s.repo.ListExceptions(ctx, orgID, mentorID, now.AddDate(0, 0, -7), now.AddDate(0, 0, 180))
	if err != nil {
		return nil, nil, err
	}
	return rules, exceptions, nil
}

// ReplaceAvailability validates and swaps a mentor's whole weekly pattern.
func (s *Service) ReplaceAvailability(ctx context.Context, orgID, mentorID string, rules []AvailabilityRule) ([]AvailabilityRule, error) {
	isMentor, err := s.repo.IsMentorInOrg(ctx, orgID, mentorID)
	if err != nil {
		return nil, err
	}
	if !isMentor {
		return nil, fmt.Errorf("%w: only a mentor can publish availability", ErrForbidden)
	}
	for i := range rules {
		rules[i].OrgID = orgID
		rules[i].MentorID = mentorID
		if rules[i].Timezone == "" {
			rules[i].Timezone = "UTC"
		}
		if rules[i].SlotMinutes == 0 {
			rules[i].SlotMinutes = 30
		}
		if err := validateRule(rules[i]); err != nil {
			return nil, err
		}
	}
	return s.repo.ReplaceRules(ctx, orgID, mentorID, rules)
}

// AddException records a one-off block or opening.
func (s *Service) AddException(ctx context.Context, e AvailabilityException) (AvailabilityException, error) {
	if e.Timezone == "" {
		e.Timezone = "UTC"
	}
	if e.SlotMinutes == 0 {
		e.SlotMinutes = 30
	}
	if err := validateException(e); err != nil {
		return AvailabilityException{}, err
	}
	return s.repo.CreateException(ctx, e)
}

// DeleteException removes one of the mentor's own overrides.
func (s *Service) DeleteException(ctx context.Context, orgID, mentorID, id string) error {
	return s.repo.DeleteException(ctx, orgID, mentorID, id)
}

// Slots returns a mentor's bookable grid for [from, to], with already-booked
// windows flagged rather than hidden.
func (s *Service) Slots(ctx context.Context, orgID, mentorID string, from, to time.Time) ([]Slot, error) {
	cfg, err := s.repo.GetConfig(ctx, orgID)
	if err != nil {
		return nil, err
	}
	if !cfg.Enabled {
		return nil, ErrBookingDisabled
	}
	rules, err := s.repo.ListRules(ctx, orgID, mentorID)
	if err != nil {
		return nil, err
	}
	exceptions, err := s.repo.ListExceptions(ctx, orgID, mentorID, from, to)
	if err != nil {
		return nil, err
	}
	busy, err := s.repo.BusyRanges(ctx, orgID, mentorID, from, to)
	if err != nil {
		return nil, err
	}
	return ExpandSlots(rules, exceptions, busy, from, to, time.Now(), cfg)
}

// ─── booking ───────────────────────────────────────────────────────────────

// BookRequest is one booking attempt. Exactly one of StudentID or BatchID is
// set; the caller (student booking themselves, mentor booking a mentee, or
// staff scheduling a cohort) is CallerID.
type BookRequest struct {
	OrgID      string
	CallerID   string
	MentorID   string
	StudentID  string
	BatchID    string
	Title      string
	Agenda     string
	MeetingURL string
	StartsAt   time.Time
	EndsAt     time.Time
}

// Book creates a session, charges a credit if the org requires one, and
// projects the result onto everyone's calendar — all in one transaction, so
// a failure at any step leaves no half-booked session and no orphaned charge.
//
// The slot-is-free check is deliberately NOT done here with a SELECT: the
// mentor_sessions_no_overlap exclusion constraint is what actually decides,
// and it decides correctly under concurrency (see ErrSlotTaken). Re-reading
// availability first would only widen the race it cannot close.
func (s *Service) Book(ctx context.Context, req BookRequest) (Session, error) {
	cfg, err := s.repo.GetConfig(ctx, req.OrgID)
	if err != nil {
		return Session{}, err
	}
	if !cfg.Enabled {
		return Session{}, ErrBookingDisabled
	}

	if (req.StudentID == "") == (req.BatchID == "") {
		return Session{}, fmt.Errorf("%w: a session is booked for either one student or one batch", ErrInvalid)
	}
	if !req.EndsAt.After(req.StartsAt) {
		return Session{}, fmt.Errorf("%w: the session must end after it starts", ErrInvalid)
	}
	if req.Title == "" {
		req.Title = "Mentor session"
	}
	if len(req.Title) > 200 {
		return Session{}, fmt.Errorf("%w: title must be 200 characters or fewer", ErrInvalid)
	}

	now := time.Now()
	if req.StartsAt.Before(now.Add(time.Duration(cfg.MinNoticeHours) * time.Hour)) {
		return Session{}, fmt.Errorf("%w: sessions must be booked at least %d hour(s) in advance", ErrInvalid, cfg.MinNoticeHours)
	}
	if req.StartsAt.After(now.AddDate(0, 0, cfg.BookingHorizonDays)) {
		return Session{}, fmt.Errorf("%w: sessions cannot be booked more than %d days ahead", ErrInvalid, cfg.BookingHorizonDays)
	}

	isMentor, err := s.repo.IsMentorInOrg(ctx, req.OrgID, req.MentorID)
	if err != nil {
		return Session{}, err
	}
	if !isMentor {
		return Session{}, fmt.Errorf("%w: that user is not a mentor in this organization", ErrInvalid)
	}

	// Authorization: a student books only for themselves; a mentor books only
	// against their own calendar. Batch scheduling is permission-gated at the
	// route, so reaching here with a BatchID is already authorized.
	if req.StudentID != "" && req.CallerID != req.StudentID && req.CallerID != req.MentorID {
		return Session{}, ErrForbidden
	}
	if req.StudentID != "" {
		member, err := s.repo.IsOrgMember(ctx, req.OrgID, req.StudentID)
		if err != nil {
			return Session{}, err
		}
		if !member {
			return Session{}, fmt.Errorf("%w: that student is not a member of this organization", ErrInvalid)
		}
	}

	var created Session
	err = s.repo.tx(ctx, func(tx pgx.Tx) error {
		// Credits and the upcoming-session cap apply to 1:1 bookings only.
		// A whole-batch session is scheduled by staff for a cohort — charging
		// every member a credit for a class they did not individually request
		// would be a silent mass debit.
		if req.StudentID != "" {
			upcoming, txErr := s.repo.CountUpcomingForStudent(ctx, tx, req.OrgID, req.StudentID)
			if txErr != nil {
				return txErr
			}
			if upcoming >= cfg.MaxUpcomingPerStudent {
				return ErrTooManyUpcoming
			}

			if cfg.RequireCredits {
				if txErr := s.repo.lockUserCredits(ctx, tx, req.OrgID, req.StudentID); txErr != nil {
					return txErr
				}
				balance, txErr := s.repo.creditBalanceTx(ctx, tx, req.OrgID, req.StudentID)
				if txErr != nil {
					return txErr
				}
				if balance < 1 {
					return ErrInsufficientCredits
				}
			}
		}

		session := Session{
			OrgID: req.OrgID, MentorID: req.MentorID, Title: req.Title,
			StartsAt: req.StartsAt, EndsAt: req.EndsAt, BookedBy: req.CallerID,
		}
		if req.StudentID != "" {
			session.StudentID = &req.StudentID
		}
		if req.BatchID != "" {
			session.BatchID = &req.BatchID
		}
		if req.Agenda != "" {
			session.Agenda = &req.Agenda
		}
		if req.MeetingURL != "" {
			session.MeetingURL = &req.MeetingURL
		}

		var txErr error
		created, txErr = s.repo.CreateSessionTx(ctx, tx, session)
		if txErr != nil {
			return txErr
		}

		if req.StudentID != "" && cfg.RequireCredits {
			if _, txErr := s.repo.insertLedgerTx(ctx, tx, req.OrgID, req.StudentID, -1,
				ReasonBooking, &created.ID, nil, nil, &req.CallerID); txErr != nil {
				return txErr
			}
		}
		return nil
	})
	if err != nil {
		return Session{}, err
	}

	// The calendar projection is created after the booking transaction
	// commits, not inside it: calendar.Service.CreateEvent opens its own
	// transaction on the same pool, and nesting one inside ours would
	// deadlock against the advisory lock we may still be holding. A booking
	// that exists without its calendar row is recoverable and visible in the
	// sessions list; a deadlocked booking request is neither.
	eventID, err := s.projectToCalendar(ctx, created)
	if err != nil {
		slog.Error("sessions: session booked but calendar projection failed",
			"session_id", created.ID, "err", err)
		return created, nil
	}
	if err := s.repo.tx(ctx, func(tx pgx.Tx) error {
		return s.repo.SetCalendarEventIDTx(ctx, tx, created.ID, eventID)
	}); err != nil {
		slog.Error("sessions: could not link calendar event to session",
			"session_id", created.ID, "event_id", eventID, "err", err)
		return created, nil
	}
	created.CalendarEventID = &eventID
	return created, nil
}

// projectToCalendar creates the calendar_events row a session shows up as.
// Attendees are the other party (or every batch member), so the session lands
// on their calendar and in their ICS feed without this package knowing how
// either works.
func (s *Service) projectToCalendar(ctx context.Context, sess Session) (string, error) {
	attendees := []string{sess.MentorID}
	if sess.StudentID != nil {
		attendees = append(attendees, *sess.StudentID)
	}
	if sess.BatchID != nil {
		members, err := s.repo.ListBatchMemberIDs(ctx, sess.OrgID, *sess.BatchID)
		if err != nil {
			return "", err
		}
		attendees = append(attendees, members...)
	}

	entityType := "mentor_session"
	endsAt := sess.EndsAt
	event := calendar.Event{
		OrgID:      sess.OrgID,
		CreatedBy:  sess.BookedBy,
		EventType:  calendar.EventTypeMentorSession,
		Title:      sess.Title,
		Notes:      sess.Agenda,
		MeetingURL: sess.MeetingURL,
		StartsAt:   sess.StartsAt,
		EndsAt:     &endsAt,
		Visibility: calendar.VisibilityShared,
		BatchID:    sess.BatchID,
		EntityType: &entityType,
		EntityID:   &sess.ID,
	}
	created, err := s.calendar.CreateEvent(ctx, event, attendees)
	if err != nil {
		return "", fmt.Errorf("sessions: project to calendar: %w", err)
	}
	return created.ID, nil
}

// ─── cancellation ──────────────────────────────────────────────────────────

// CancelResult reports what a cancellation actually did, so the UI can say
// "credit returned" or "cancelled inside the 12-hour window, credit
// forfeited" rather than guessing.
type CancelResult struct {
	Session       Session `json:"session"`
	CreditRefund  bool    `json:"credit_refunded"`
	WithinCutoff  bool    `json:"within_cutoff"`
	CutoffHours   int     `json:"cutoff_hours"`
	AlreadyClosed bool    `json:"already_closed"`
}

// Cancel cancels a scheduled session.
//
// Refund policy: the credit comes back when the cancellation lands earlier
// than cancel_cutoff_hours before the start, OR when the mentor is the one
// cancelling — a student must never pay for the mentor's change of plans, no
// matter how late it is. A late student cancellation forfeits the credit,
// which is the entire point of having a cutoff.
func (s *Service) Cancel(ctx context.Context, orgID, sessionID, callerID, reason string) (CancelResult, error) {
	cfg, err := s.repo.GetConfig(ctx, orgID)
	if err != nil {
		return CancelResult{}, err
	}

	var result CancelResult
	result.CutoffHours = cfg.CancelCutoffHours

	err = s.repo.tx(ctx, func(tx pgx.Tx) error {
		sess, txErr := s.repo.getSessionUnscoped(ctx, tx, orgID, sessionID)
		if txErr != nil {
			return txErr
		}
		if sess.MentorID != callerID && (sess.StudentID == nil || *sess.StudentID != callerID) && sess.BookedBy != callerID {
			return ErrForbidden
		}
		if sess.Status != StatusScheduled {
			result.Session = sess
			result.AlreadyClosed = true
			return nil
		}

		var reasonPtr *string
		if reason != "" {
			reasonPtr = &reason
		}
		transitioned, txErr := s.repo.CancelSessionTx(ctx, tx, sessionID, callerID, reasonPtr)
		if txErr != nil {
			return txErr
		}
		if !transitioned {
			result.Session = sess
			result.AlreadyClosed = true
			return nil
		}

		cutoff := sess.StartsAt.Add(-time.Duration(cfg.CancelCutoffHours) * time.Hour)
		result.WithinCutoff = time.Now().After(cutoff)
		byMentor := callerID == sess.MentorID

		if sess.StudentID != nil && cfg.RequireCredits && (!result.WithinCutoff || byMentor) {
			if txErr := s.repo.lockUserCredits(ctx, tx, orgID, *sess.StudentID); txErr != nil {
				return txErr
			}
			// session_credit_ledger_refund_uq makes this at-most-once: a
			// retried cancel inserts nothing and reports refunded=false
			// rather than minting a second credit.
			inserted, txErr := s.repo.insertLedgerTx(ctx, tx, orgID, *sess.StudentID, 1,
				ReasonCancellationRefund, &sessionID, nil, nil, &callerID)
			if txErr != nil {
				return txErr
			}
			result.CreditRefund = inserted
		}

		sess.Status = StatusCancelled
		sess.CancelledBy = &callerID
		sess.CancelReason = reasonPtr
		result.Session = sess
		return nil
	})
	if err != nil {
		return CancelResult{}, err
	}

	// Clear the calendar entry too, so a cancelled session stops occupying
	// both parties' days. Best-effort for the same reason projection is:
	// the booking is already cancelled, and failing the whole request now
	// would leave the caller thinking it wasn't.
	if !result.AlreadyClosed && result.Session.CalendarEventID != nil {
		if err := s.calendar.DeleteEvent(ctx, orgID, *result.Session.CalendarEventID, callerID, calendar.ScopeSingle, nil); err != nil {
			slog.Error("sessions: session cancelled but calendar event remains",
				"session_id", sessionID, "event_id", *result.Session.CalendarEventID, "err", err)
		}
	}
	return result, nil
}

// ─── outcome, feedback, notes ──────────────────────────────────────────────

// SetOutcome marks a session completed or no_show. Only the mentor decides
// this — a student marking their own no-show away would erase the record the
// policy depends on.
func (s *Service) SetOutcome(ctx context.Context, orgID, sessionID, callerID, status string) (Session, error) {
	if status != StatusCompleted && status != StatusNoShow {
		return Session{}, fmt.Errorf("%w: outcome must be completed or no_show", ErrInvalid)
	}
	sess, err := s.repo.GetSession(ctx, orgID, sessionID, callerID)
	if err != nil {
		return Session{}, err
	}
	if sess.MentorID != callerID {
		return Session{}, ErrForbidden
	}
	if sess.StartsAt.After(time.Now()) {
		return Session{}, fmt.Errorf("%w: a session cannot be closed out before it starts", ErrInvalid)
	}
	return s.repo.SetOutcome(ctx, orgID, sessionID, status)
}

// SubmitFeedback records one party's rating of a session. Both sides may
// rate, once each, and only after the session has actually happened —
// rating a session that has not started yet is rating nothing.
func (s *Service) SubmitFeedback(ctx context.Context, orgID, sessionID, callerID string, rating int, comment string) (Feedback, error) {
	if rating < 1 || rating > 5 {
		return Feedback{}, fmt.Errorf("%w: rating must be between 1 and 5", ErrInvalid)
	}
	if len(comment) > 2000 {
		return Feedback{}, fmt.Errorf("%w: comment must be 2000 characters or fewer", ErrInvalid)
	}
	sess, err := s.repo.GetSession(ctx, orgID, sessionID, callerID)
	if err != nil {
		return Feedback{}, err
	}
	if sess.Status == StatusCancelled {
		return Feedback{}, fmt.Errorf("%w: a cancelled session cannot be rated", ErrInvalid)
	}
	if sess.EndsAt.After(time.Now()) {
		return Feedback{}, fmt.Errorf("%w: feedback opens once the session has ended", ErrInvalid)
	}

	role := RoleStudent
	if callerID == sess.MentorID {
		role = RoleMentor
	}
	var commentPtr *string
	if comment != "" {
		commentPtr = &comment
	}
	return s.repo.UpsertFeedback(ctx, Feedback{
		SessionID: sessionID, AuthorID: callerID, AuthorRole: role,
		Rating: rating, Comment: commentPtr,
	})
}

// SaveNotes writes the mentor's write-up of a session.
func (s *Service) SaveNotes(ctx context.Context, orgID, sessionID, callerID, body string, visibleToStudent bool) (Notes, error) {
	if len(body) > 20000 {
		return Notes{}, fmt.Errorf("%w: notes must be 20000 characters or fewer", ErrInvalid)
	}
	sess, err := s.repo.GetSession(ctx, orgID, sessionID, callerID)
	if err != nil {
		return Notes{}, err
	}
	if sess.MentorID != callerID {
		return Notes{}, ErrForbidden
	}
	return s.repo.UpsertNotes(ctx, Notes{
		SessionID: sessionID, MentorID: callerID, Body: body, VisibleToStudent: visibleToStudent,
	})
}

// SessionDetail is one session plus everything the detail page renders.
type SessionDetail struct {
	Session  Session    `json:"session"`
	Feedback []Feedback `json:"feedback"`
	Notes    *Notes     `json:"notes"`
	// MyFeedback is the caller's own rating, if they have left one — so the
	// form renders pre-filled for an edit instead of inviting a duplicate.
	MyFeedback *Feedback `json:"my_feedback"`
}

// GetDetail returns a session with its feedback and (where the caller is
// allowed to see them) the mentor's notes.
func (s *Service) GetDetail(ctx context.Context, orgID, sessionID, callerID string) (SessionDetail, error) {
	sess, err := s.repo.GetSession(ctx, orgID, sessionID, callerID)
	if err != nil {
		return SessionDetail{}, err
	}
	feedback, err := s.repo.ListFeedback(ctx, sessionID)
	if err != nil {
		return SessionDetail{}, err
	}
	notes, err := s.repo.GetNotes(ctx, sessionID, callerID == sess.MentorID)
	if err != nil {
		return SessionDetail{}, err
	}

	detail := SessionDetail{Session: sess, Feedback: feedback, Notes: notes}
	for i := range feedback {
		if feedback[i].AuthorID == callerID {
			detail.MyFeedback = &feedback[i]
			break
		}
	}
	return detail, nil
}

// ListSessions returns the caller's sessions for the given scope.
func (s *Service) ListSessions(ctx context.Context, orgID, callerID, scope string, limit int) ([]Session, error) {
	switch scope {
	case ScopeUpcoming, ScopePast, ScopeAll:
	case "":
		scope = ScopeAll
	default:
		return nil, fmt.Errorf("%w: scope must be upcoming, past, or all", ErrInvalid)
	}
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	return s.repo.ListSessions(ctx, orgID, callerID, scope, limit)
}

// MenteeProgress returns one mentee's full history with the calling mentor.
func (s *Service) MenteeProgress(ctx context.Context, orgID, mentorID, studentID string) (MenteeProgress, error) {
	isMentor, err := s.repo.IsMentorInOrg(ctx, orgID, mentorID)
	if err != nil {
		return MenteeProgress{}, err
	}
	if !isMentor {
		return MenteeProgress{}, ErrForbidden
	}
	return s.repo.MenteeProgress(ctx, orgID, mentorID, studentID)
}

// Reschedule moves a session and drags its calendar entry along with it.
// Either party may move a session they are part of; the same exclusion
// constraint that guards booking rejects a move onto a busy window.
func (s *Service) Reschedule(ctx context.Context, orgID, sessionID, callerID string, startsAt, endsAt time.Time) (Session, error) {
	if !endsAt.After(startsAt) {
		return Session{}, fmt.Errorf("%w: the session must end after it starts", ErrInvalid)
	}
	cfg, err := s.repo.GetConfig(ctx, orgID)
	if err != nil {
		return Session{}, err
	}
	if startsAt.Before(time.Now().Add(time.Duration(cfg.MinNoticeHours) * time.Hour)) {
		return Session{}, fmt.Errorf("%w: sessions must be moved to a time at least %d hour(s) away", ErrInvalid, cfg.MinNoticeHours)
	}

	sess, err := s.repo.GetSession(ctx, orgID, sessionID, callerID)
	if err != nil {
		return Session{}, err
	}
	if sess.MentorID != callerID && (sess.StudentID == nil || *sess.StudentID != callerID) {
		return Session{}, ErrForbidden
	}
	if sess.Status != StatusScheduled {
		return Session{}, fmt.Errorf("%w: only a scheduled session can be moved", ErrInvalid)
	}

	moved, err := s.repo.Reschedule(ctx, orgID, sessionID, startsAt, endsAt)
	if err != nil {
		return Session{}, err
	}

	if moved.CalendarEventID != nil {
		patch := calendar.Event{
			EventType: calendar.EventTypeMentorSession, Title: moved.Title,
			Notes: moved.Agenda, MeetingURL: moved.MeetingURL,
			StartsAt: startsAt, EndsAt: &endsAt, Visibility: calendar.VisibilityShared,
			BatchID: moved.BatchID,
		}
		if _, err := s.calendar.UpdateEvent(ctx, orgID, *moved.CalendarEventID, callerID, calendar.ScopeSingle, nil, patch); err != nil {
			slog.Error("sessions: session moved but calendar event still shows the old time",
				"session_id", sessionID, "event_id", *moved.CalendarEventID, "err", err)
		}
	}
	return moved, nil
}

// CreditSummary is a student's balance plus the recent movements behind it.
type CreditSummary struct {
	Balance int           `json:"balance"`
	Entries []LedgerEntry `json:"entries"`
}

// Credits returns a user's balance and recent ledger.
func (s *Service) Credits(ctx context.Context, orgID, userID string) (CreditSummary, error) {
	balance, err := s.repo.CreditBalance(ctx, orgID, userID)
	if err != nil {
		return CreditSummary{}, err
	}
	entries, err := s.repo.ListLedger(ctx, orgID, userID, 50)
	if err != nil {
		return CreditSummary{}, err
	}
	return CreditSummary{Balance: balance, Entries: entries}, nil
}

// GrantCredits adds (or, with a negative delta, removes) credits by admin
// action.
func (s *Service) GrantCredits(ctx context.Context, orgID, userID string, delta int, note, actorID string) (int, error) {
	if delta == 0 {
		return 0, fmt.Errorf("%w: the number of credits must not be zero", ErrInvalid)
	}
	if delta > 1000 || delta < -1000 {
		return 0, fmt.Errorf("%w: grant at most 1000 credits at a time", ErrInvalid)
	}
	member, err := s.repo.IsOrgMember(ctx, orgID, userID)
	if err != nil {
		return 0, err
	}
	if !member {
		return 0, fmt.Errorf("%w: that user is not a member of this organization", ErrInvalid)
	}
	return s.repo.GrantCredits(ctx, orgID, userID, delta, note, actorID)
}
