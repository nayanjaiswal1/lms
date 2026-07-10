package calendar

import (
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/httputil"
)

type Handler struct {
	service *Service
	cfg     *config.Config
}

func ctxClaims(w http.ResponseWriter, r *http.Request) (*auth.Claims, bool) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return nil, false
	}
	return claims, true
}

func writeDomainError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrNotFound):
		httputil.WriteError(w, http.StatusNotFound, "Not found.")
	case errors.Is(err, ErrForbidden):
		httputil.WriteError(w, http.StatusForbidden, "You do not have permission to do that.")
	case errors.Is(err, ErrFeedTokenExists):
		httputil.WriteError(w, http.StatusConflict, "A feed URL has already been issued. Pass rotate=true to reissue it.")
	case errors.Is(err, ErrInvalid):
		httputil.WriteError(w, http.StatusUnprocessableEntity, err.Error())
	default:
		httputil.WriteError(w, http.StatusInternalServerError, "Something went wrong.")
	}
}

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
}

func urlParam(r *http.Request, key string) string {
	return chi.URLParam(r, key)
}

func queryTime(r *http.Request, key string) (time.Time, bool) {
	v := r.URL.Query().Get(key)
	if v == "" {
		return time.Time{}, false
	}
	t, err := time.Parse(time.RFC3339, v)
	if err != nil {
		return time.Time{}, false
	}
	return t, true
}

// eventRequest is the JSON shape for both POST /events (all fields
// meaningful) and PATCH /events/{id} (only present fields are applied —
// see Handler.UpdateEvent's merge onto the existing row).
type eventRequest struct {
	EventType       *string  `json:"event_type"`
	Title           *string  `json:"title"`
	Notes           *string  `json:"notes"`
	MeetingURL      *string  `json:"meeting_url"`
	StartsAt        *string  `json:"starts_at"`
	EndsAt          *string  `json:"ends_at"`
	AllDay          *bool    `json:"all_day"`
	Visibility      *string  `json:"visibility"`
	BatchID         *string  `json:"batch_id"`
	CourseID        *string  `json:"course_id"`
	EntityType      *string  `json:"entity_type"`
	EntityID        *string  `json:"entity_id"`
	RecurrenceRule  *string  `json:"recurrence_rule"`
	AttendeeUserIDs []string `json:"attendee_user_ids"`
}

// applyTo merges the request's present (non-nil) fields onto base and
// returns the result. Time fields are parsed here so a malformed timestamp
// surfaces as a normal 422 rather than a service-level error.
func (req eventRequest) applyTo(base Event) (Event, error) {
	if req.EventType != nil {
		base.EventType = *req.EventType
	}
	if req.Title != nil {
		base.Title = *req.Title
	}
	if req.Notes != nil {
		base.Notes = req.Notes
	}
	if req.MeetingURL != nil {
		base.MeetingURL = req.MeetingURL
	}
	if req.StartsAt != nil {
		t, err := time.Parse(time.RFC3339, *req.StartsAt)
		if err != nil {
			return Event{}, errInvalidf("starts_at must be RFC3339")
		}
		base.StartsAt = t
	}
	if req.EndsAt != nil {
		if *req.EndsAt == "" {
			base.EndsAt = nil
		} else {
			t, err := time.Parse(time.RFC3339, *req.EndsAt)
			if err != nil {
				return Event{}, errInvalidf("ends_at must be RFC3339")
			}
			base.EndsAt = &t
		}
	}
	if req.AllDay != nil {
		base.AllDay = *req.AllDay
	}
	if req.Visibility != nil {
		base.Visibility = *req.Visibility
	}
	if req.BatchID != nil {
		if *req.BatchID == "" {
			base.BatchID = nil
		} else {
			base.BatchID = req.BatchID
		}
	}
	if req.CourseID != nil {
		if *req.CourseID == "" {
			base.CourseID = nil
		} else {
			base.CourseID = req.CourseID
		}
	}
	if req.EntityType != nil {
		base.EntityType = req.EntityType
	}
	if req.EntityID != nil {
		base.EntityID = req.EntityID
	}
	if req.RecurrenceRule != nil {
		if *req.RecurrenceRule == "" {
			base.RecurrenceRule = nil
		} else {
			base.RecurrenceRule = req.RecurrenceRule
		}
	}
	return base, nil
}

func errInvalidf(msg string) error {
	return &invalidErr{msg: msg}
}

type invalidErr struct{ msg string }

func (e *invalidErr) Error() string { return e.msg }
func (e *invalidErr) Unwrap() error { return ErrInvalid }

// ─── GET /api/calendar/events ───────────────────────────────────────────────

func (h *Handler) ListEvents(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	from, ok := queryTime(r, "from")
	if !ok {
		httputil.WriteError(w, http.StatusUnprocessableEntity, "from must be an RFC3339 timestamp.")
		return
	}
	to, ok := queryTime(r, "to")
	if !ok {
		httputil.WriteError(w, http.StatusUnprocessableEntity, "to must be an RFC3339 timestamp.")
		return
	}
	events, err := h.service.ListRange(r.Context(), claims.OrgID, claims.UserID, from, to)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, events)
}

// ─── POST /api/calendar/events ──────────────────────────────────────────────

func (h *Handler) CreateEvent(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req eventRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	e, err := req.applyTo(Event{Visibility: VisibilityPrivate})
	if err != nil {
		writeDomainError(w, err)
		return
	}
	e.OrgID = claims.OrgID
	e.CreatedBy = claims.UserID

	created, err := h.service.CreateEvent(r.Context(), e, req.AttendeeUserIDs)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, created)
}

// ─── GET /api/calendar/events/{id} ──────────────────────────────────────────

type eventDetail struct {
	Event
	Attendees      []Attendee    `json:"attendees"`
	PendingInvites []EventInvite `json:"pending_invites"`
}

func (h *Handler) GetEvent(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	event, attendees, pendingInvites, err := h.service.GetEvent(r.Context(), claims.OrgID, urlParam(r, "eventID"), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, eventDetail{Event: event, Attendees: attendees, PendingInvites: pendingInvites})
}

// ─── PATCH /api/calendar/events/{id}?scope=single|series ────────────────────

func (h *Handler) UpdateEvent(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	eventID := urlParam(r, "eventID")

	scope := r.URL.Query().Get("scope")
	if scope == "" {
		scope = ScopeSeries
	}
	if !IsValidScope(scope) {
		httputil.WriteError(w, http.StatusUnprocessableEntity, "scope must be single or series.")
		return
	}

	var occurrenceStartsAt *time.Time
	if v := r.URL.Query().Get("occurrence_starts_at"); v != "" {
		t, err := time.Parse(time.RFC3339, v)
		if err != nil {
			httputil.WriteError(w, http.StatusUnprocessableEntity, "occurrence_starts_at must be an RFC3339 timestamp.")
			return
		}
		occurrenceStartsAt = &t
	}

	current, _, _, err := h.service.GetEvent(r.Context(), claims.OrgID, eventID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	var req eventRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	patch, err := req.applyTo(current)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	updated, err := h.service.UpdateEvent(r.Context(), claims.OrgID, eventID, claims.UserID, scope, occurrenceStartsAt, patch)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, updated)
}

// ─── DELETE /api/calendar/events/{id}?scope=single|series ───────────────────

func (h *Handler) DeleteEvent(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	eventID := urlParam(r, "eventID")

	scope := r.URL.Query().Get("scope")
	if scope == "" {
		scope = ScopeSeries
	}
	if !IsValidScope(scope) {
		httputil.WriteError(w, http.StatusUnprocessableEntity, "scope must be single or series.")
		return
	}

	var occurrenceStartsAt *time.Time
	if v := r.URL.Query().Get("occurrence_starts_at"); v != "" {
		t, err := time.Parse(time.RFC3339, v)
		if err != nil {
			httputil.WriteError(w, http.StatusUnprocessableEntity, "occurrence_starts_at must be an RFC3339 timestamp.")
			return
		}
		occurrenceStartsAt = &t
	}

	if err := h.service.DeleteEvent(r.Context(), claims.OrgID, eventID, claims.UserID, scope, occurrenceStartsAt); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"cancelled": true})
}

// ─── PATCH /api/calendar/events/{id}/notes ──────────────────────────────────

func (h *Handler) UpdateNotes(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Notes *string `json:"notes"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	updated, err := h.service.UpdateNotes(r.Context(), claims.OrgID, urlParam(r, "eventID"), claims.UserID, req.Notes)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, updated)
}

// ─── PATCH /api/calendar/events/{id}/complete ───────────────────────────────

func (h *Handler) SetCompleted(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Completed bool `json:"completed"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	updated, err := h.service.SetCompleted(r.Context(), claims.OrgID, urlParam(r, "eventID"), claims.UserID, req.Completed)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, updated)
}

// ─── POST /api/calendar/events/{id}/rsvp ────────────────────────────────────

func (h *Handler) RSVP(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		RSVPStatus string `json:"rsvp_status"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	attendee, err := h.service.RSVP(r.Context(), urlParam(r, "eventID"), claims.UserID, req.RSVPStatus)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, attendee)
}

// ─── POST /api/calendar/events/{id}/invite ──────────────────────────────────

func (h *Handler) InviteExternal(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Email string `json:"email"`
		Role  string `json:"role"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.Role == "" {
		req.Role = AttendeeRoleViewer
	}
	invite, token, err := h.service.InviteExternal(r.Context(), claims.OrgID, urlParam(r, "eventID"), claims.UserID, req.Email, req.Role)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, map[string]any{
		"invite": invite,
		"token":  token,
	})
}

// ─── GET /api/calendar/invites/{token}/accept ───────────────────────────────
// No auth required — the token itself is the proof of access. Mounted via
// RegisterPublicRoutes.

func (h *Handler) AcceptInvite(w http.ResponseWriter, r *http.Request) {
	event, err := h.service.AcceptInvite(r.Context(), urlParam(r, "token"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, event)
}

// ─── GET /api/calendar/events.ics ───────────────────────────────────────────
// No auth required — ?token= (a calendar_feed_tokens entry) is the proof of
// access; external calendar clients (Google Calendar, Outlook) cannot carry
// session cookies. Mounted via RegisterPublicRoutes.

func (h *Handler) EventsICS(w http.ResponseWriter, r *http.Request) {
	token := r.URL.Query().Get("token")
	if token == "" {
		httputil.WriteError(w, http.StatusBadRequest, "token is required.")
		return
	}
	userID, orgID, err := h.service.VerifyFeedToken(r.Context(), token)
	if err != nil {
		httputil.WriteError(w, http.StatusUnauthorized, "Invalid or revoked feed token.")
		return
	}

	// -1 month to +11 months spans 365 days — Service.ListRange rejects
	// anything over maxRangeWindow (366 days), and a full -1/+1 year window
	// (~395 days) exceeds it.
	from := time.Now().AddDate(0, -1, 0)
	to := time.Now().AddDate(0, 11, 0)
	events, err := h.service.ListRange(r.Context(), orgID, userID, from, to)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	w.Header().Set("Content-Type", "text/calendar; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(BuildICS(events)))
}

// ─── POST /api/calendar/events.ics/token?rotate=true ────────────────────────
// Authenticated — mints (or, with ?rotate=true, reissues) the caller's
// personal feed URL. See Service.GetOrCreateFeedURL / ErrFeedTokenExists.

func (h *Handler) MintFeedToken(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	rotate := r.URL.Query().Get("rotate") == "true"
	url, err := h.service.GetOrCreateFeedURL(r.Context(), h.cfg.BackendURL, claims.OrgID, claims.UserID, rotate)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"url": url})
}
