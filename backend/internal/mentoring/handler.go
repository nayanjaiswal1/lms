package mentoring

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/httputil"
)

// Fine-grained RBAC permission codes for mentor-ticket assignment — mirrors
// backend/db/migrations/022_mentor_ticket_permissions.sql.
const (
	PermissionAssignTickets = "mentoring.assign_tickets"
	PermissionManageReports = "mentoring.manage_reports"
	// PermissionVerifyMentors mirrors 006_mentor_verification.sql.
	PermissionVerifyMentors = "mentoring.verify_mentors"
)

type Handler struct {
	service  *Service
	authzSvc *authz.Service
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
	case errors.Is(err, ErrTicketAlreadyClaimed):
		httputil.WriteError(w, http.StatusConflict, "This ticket has already been claimed.")
	case errors.Is(err, ErrAlreadyPurchased):
		httputil.WriteError(w, http.StatusConflict, "You have already purchased this course.")
	case errors.Is(err, ErrAlreadyHasMentor):
		httputil.WriteError(w, http.StatusConflict, "You already have an active mentor request.")
	case errors.Is(err, ErrChangeRequestPending):
		httputil.WriteError(w, http.StatusConflict, "A mentor change request is already pending for this ticket.")
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

func queryStrPtr(r *http.Request, key string) *string {
	v := r.URL.Query().Get(key)
	if v == "" {
		return nil
	}
	return &v
}
