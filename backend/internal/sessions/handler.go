package sessions

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

type Handler struct {
	service *Service
}

func ctxClaims(w http.ResponseWriter, r *http.Request) (*auth.Claims, bool) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return nil, false
	}
	return claims, true
}

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
}

func writeDomainError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrNotFound):
		httputil.WriteError(w, http.StatusNotFound, "Not found.")
	case errors.Is(err, ErrForbidden):
		httputil.WriteError(w, http.StatusForbidden, "You do not have permission to do that.")
	case errors.Is(err, ErrBookingDisabled):
		httputil.WriteError(w, http.StatusForbidden, "Session booking is turned off for your organization.")
	case errors.Is(err, ErrSlotTaken):
		httputil.WriteError(w, http.StatusConflict, "That slot was just booked by someone else. Pick another time.")
	case errors.Is(err, ErrInsufficientCredits):
		httputil.WriteError(w, http.StatusPaymentRequired, "You have no session credits left. Buy a pack to book another session.")
	case errors.Is(err, ErrTooManyUpcoming):
		httputil.WriteError(w, http.StatusConflict, "You have reached the limit of upcoming sessions. Complete or cancel one first.")
	case errors.Is(err, ErrInvalid):
		httputil.WriteError(w, http.StatusUnprocessableEntity, err.Error())
	default:
		httputil.WriteError(w, http.StatusInternalServerError, "Something went wrong.")
	}
}

// parseRange reads ?from=&to= as RFC3339, defaulting to the next 14 days —
// the window the booking grid opens on.
func parseRange(r *http.Request) (time.Time, time.Time, error) {
	now := time.Now()
	from, to := now, now.AddDate(0, 0, 14)
	if v := r.URL.Query().Get("from"); v != "" {
		parsed, err := time.Parse(time.RFC3339, v)
		if err != nil {
			return time.Time{}, time.Time{}, err
		}
		from = parsed
	}
	if v := r.URL.Query().Get("to"); v != "" {
		parsed, err := time.Parse(time.RFC3339, v)
		if err != nil {
			return time.Time{}, time.Time{}, err
		}
		to = parsed
	}
	return from, to, nil
}

// ─── config ────────────────────────────────────────────────────────────────

// GetConfig returns the org's booking policy plus the caller's own credit
// balance — one round trip for everything the booking UI needs before it can
// render a single button.
func (h *Handler) GetConfig(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	cfg, err := h.service.GetConfig(r.Context(), claims.OrgID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	credits, err := h.service.Credits(r.Context(), claims.OrgID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"config":  cfg,
		"balance": credits.Balance,
	})
}

// UpdateConfig writes the org's booking policy. Route-gated by
// PermissionManageBooking.
func (h *Handler) UpdateConfig(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req Config
	if !decodeJSON(w, r, &req) {
		return
	}
	req.OrgID = claims.OrgID
	cfg, err := h.service.UpdateConfig(r.Context(), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, cfg)
}

// ─── availability ──────────────────────────────────────────────────────────

// GetMyAvailability returns the calling mentor's own weekly pattern.
func (h *Handler) GetMyAvailability(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	rules, exceptions, err := h.service.ListAvailability(r.Context(), claims.OrgID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"rules": rules, "exceptions": exceptions})
}

// ReplaceMyAvailability swaps the calling mentor's whole weekly pattern.
func (h *Handler) ReplaceMyAvailability(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Rules []AvailabilityRule `json:"rules"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	rules, err := h.service.ReplaceAvailability(r.Context(), claims.OrgID, claims.UserID, req.Rules)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"rules": rules})
}

// AddException records a one-off block or extra opening.
func (h *Handler) AddException(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req AvailabilityException
	if !decodeJSON(w, r, &req) {
		return
	}
	req.OrgID = claims.OrgID
	req.MentorID = claims.UserID
	created, err := h.service.AddException(r.Context(), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, created)
}

// DeleteException removes one of the calling mentor's overrides.
func (h *Handler) DeleteException(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.DeleteException(r.Context(), claims.OrgID, claims.UserID, chi.URLParam(r, "exceptionID")); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// GetSlots returns a mentor's bookable grid, taken windows included.
func (h *Handler) GetSlots(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	from, to, err := parseRange(r)
	if err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "from and to must be RFC3339 timestamps.")
		return
	}
	slots, err := h.service.Slots(r.Context(), claims.OrgID, chi.URLParam(r, "mentorID"), from, to)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"slots": slots})
}

// ─── sessions ──────────────────────────────────────────────────────────────

// Book creates a 1:1 session. A student booking themselves may omit
// student_id; a mentor booking a mentee must supply it.
func (h *Handler) Book(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		MentorID   string    `json:"mentor_id"`
		StudentID  string    `json:"student_id"`
		Title      string    `json:"title"`
		Agenda     string    `json:"agenda"`
		MeetingURL string    `json:"meeting_url"`
		StartsAt   time.Time `json:"starts_at"`
		EndsAt     time.Time `json:"ends_at"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.StudentID == "" && req.MentorID != claims.UserID {
		// The caller is the student — the common case, and the one where
		// making the client send its own id is a way to get it wrong.
		req.StudentID = claims.UserID
	}

	session, err := h.service.Book(r.Context(), BookRequest{
		OrgID: claims.OrgID, CallerID: claims.UserID, MentorID: req.MentorID,
		StudentID: req.StudentID, Title: req.Title, Agenda: req.Agenda,
		MeetingURL: req.MeetingURL, StartsAt: req.StartsAt, EndsAt: req.EndsAt,
	})
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, session)
}

// BookForBatch schedules one session for a whole cohort. Route-gated by
// PermissionManageBooking — no credits are charged (see Book).
func (h *Handler) BookForBatch(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		MentorID   string    `json:"mentor_id"`
		Title      string    `json:"title"`
		Agenda     string    `json:"agenda"`
		MeetingURL string    `json:"meeting_url"`
		StartsAt   time.Time `json:"starts_at"`
		EndsAt     time.Time `json:"ends_at"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	session, err := h.service.Book(r.Context(), BookRequest{
		OrgID: claims.OrgID, CallerID: claims.UserID, MentorID: req.MentorID,
		BatchID: chi.URLParam(r, "batchID"), Title: req.Title, Agenda: req.Agenda,
		MeetingURL: req.MeetingURL, StartsAt: req.StartsAt, EndsAt: req.EndsAt,
	})
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, session)
}

// ListSessions returns the caller's sessions for ?scope=upcoming|past|all.
func (h *Handler) ListSessions(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	list, err := h.service.ListSessions(r.Context(), claims.OrgID, claims.UserID, r.URL.Query().Get("scope"), limit)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"sessions": list})
}

// GetSession returns one session with its feedback and (mentor only) notes.
func (h *Handler) GetSession(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	detail, err := h.service.GetDetail(r.Context(), claims.OrgID, chi.URLParam(r, "sessionID"), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, detail)
}

// Cancel cancels a session and reports whether the credit came back.
func (h *Handler) Cancel(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Reason string `json:"reason"`
	}
	// A cancellation with no body is valid — the reason is optional.
	_ = json.NewDecoder(r.Body).Decode(&req)

	result, err := h.service.Cancel(r.Context(), claims.OrgID, chi.URLParam(r, "sessionID"), claims.UserID, req.Reason)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, result)
}

// Reschedule moves a session to a new window.
func (h *Handler) Reschedule(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		StartsAt time.Time `json:"starts_at"`
		EndsAt   time.Time `json:"ends_at"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	session, err := h.service.Reschedule(r.Context(), claims.OrgID, chi.URLParam(r, "sessionID"), claims.UserID, req.StartsAt, req.EndsAt)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, session)
}

// SetOutcome marks a session completed or no_show (mentor only).
func (h *Handler) SetOutcome(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Status string `json:"status"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	session, err := h.service.SetOutcome(r.Context(), claims.OrgID, chi.URLParam(r, "sessionID"), claims.UserID, req.Status)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, session)
}

// SubmitFeedback records the caller's rating of a session.
func (h *Handler) SubmitFeedback(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Rating  int    `json:"rating"`
		Comment string `json:"comment"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	feedback, err := h.service.SubmitFeedback(r.Context(), claims.OrgID, chi.URLParam(r, "sessionID"), claims.UserID, req.Rating, req.Comment)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, feedback)
}

// SaveNotes writes the mentor's write-up of a session.
func (h *Handler) SaveNotes(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Body             string `json:"body"`
		VisibleToStudent bool   `json:"visible_to_student"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	notes, err := h.service.SaveNotes(r.Context(), claims.OrgID, chi.URLParam(r, "sessionID"), claims.UserID, req.Body, req.VisibleToStudent)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, notes)
}

// GetMenteeProgress returns one mentee's full history with the calling mentor.
func (h *Handler) GetMenteeProgress(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	progress, err := h.service.MenteeProgress(r.Context(), claims.OrgID, claims.UserID, chi.URLParam(r, "studentID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, progress)
}

// ─── credits & packs ───────────────────────────────────────────────────────

// GetCredits returns the caller's balance and recent ledger movements.
func (h *Handler) GetCredits(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	summary, err := h.service.Credits(r.Context(), claims.OrgID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, summary)
}

// ListPacks returns the packs on sale. ?all=true (admin surface) includes
// archived ones.
func (h *Handler) ListPacks(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	packs, err := h.service.ListPacks(r.Context(), claims.OrgID, r.URL.Query().Get("all") != "true")
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"packs": packs})
}

// SavePack creates or updates a credit pack. Route-gated by
// PermissionManageBooking.
func (h *Handler) SavePack(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req CreditPack
	if !decodeJSON(w, r, &req) {
		return
	}
	req.OrgID = claims.OrgID
	req.ID = chi.URLParam(r, "packID")
	pack, err := h.service.SavePack(r.Context(), req, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, pack)
}

// BuyPack opens a gateway checkout for a credit pack.
func (h *Handler) BuyPack(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Provider string `json:"provider"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)

	checkout, err := h.service.StartPackCheckout(r.Context(), claims.OrgID, claims.UserID, chi.URLParam(r, "packID"), req.Provider)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, checkout)
}

// GrantCredits adds or removes a user's credits by admin action.
// Route-gated by PermissionManageBooking.
func (h *Handler) GrantCredits(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		UserID string `json:"user_id"`
		Delta  int    `json:"delta"`
		Note   string `json:"note"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	balance, err := h.service.GrantCredits(r.Context(), claims.OrgID, req.UserID, req.Delta, req.Note, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"balance": balance})
}
