package notifications

import (
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// defaultListLimit caps GET /api/notifications' page size — no pagination
// cursor yet (kind-herding-cookie.md §0.6 explicitly defers a notification
// preferences matrix too; add pagination when a real user has enough
// notifications for it to matter).
const defaultListLimit = 50

// Handler exposes the notifications domain over HTTP. Every route is scoped
// to the authenticated caller's own rows (see Repo.List/MarkRead's own
// WHERE user_id = $1 clauses) — there is no "view another user's
// notifications" capability at all, so no role check beyond RequireAuth is
// needed here.
type Handler struct {
	service *Service
}

// NewHandler builds the notifications HTTP handler.
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func claimsOrUnauthorized(w http.ResponseWriter, r *http.Request) (userID string, ok bool) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return "", false
	}
	return claims.UserID, true
}

// List handles GET /api/notifications.
func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	userID, ok := claimsOrUnauthorized(w, r)
	if !ok {
		return
	}
	notifs, err := h.service.List(r.Context(), userID, defaultListLimit)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Could not load notifications.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, ListView{Notifications: notifs})
}

// UnreadCount handles GET /api/notifications/unread-count.
func (h *Handler) UnreadCount(w http.ResponseWriter, r *http.Request) {
	userID, ok := claimsOrUnauthorized(w, r)
	if !ok {
		return
	}
	count, err := h.service.UnreadCount(r.Context(), userID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Could not load unread count.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, UnreadCountView{UnreadCount: count})
}

// MarkRead handles POST /api/notifications/{id}/read.
func (h *Handler) MarkRead(w http.ResponseWriter, r *http.Request) {
	userID, ok := claimsOrUnauthorized(w, r)
	if !ok {
		return
	}
	if err := h.service.MarkRead(r.Context(), userID, chi.URLParam(r, "id")); err != nil {
		if errors.Is(err, ErrNotFound) {
			httputil.WriteError(w, http.StatusNotFound, "Notification not found.")
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "Could not mark notification read.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Notification marked read."})
}

// MarkAllRead handles POST /api/notifications/read-all.
func (h *Handler) MarkAllRead(w http.ResponseWriter, r *http.Request) {
	userID, ok := claimsOrUnauthorized(w, r)
	if !ok {
		return
	}
	if err := h.service.MarkAllRead(r.Context(), userID); err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Could not mark notifications read.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "All notifications marked read."})
}
