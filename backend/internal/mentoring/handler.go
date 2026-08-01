package mentoring

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

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

var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound:             {Status: http.StatusNotFound, Message: "Not found."},
	ErrForbidden:            {Status: http.StatusForbidden, Message: "You do not have permission to do that."},
	ErrTicketAlreadyClaimed: {Status: http.StatusConflict, Message: "This ticket has already been claimed."},
	ErrAlreadyPurchased:     {Status: http.StatusConflict, Message: "You have already purchased this course."},
	ErrAlreadyHasMentor:     {Status: http.StatusConflict, Message: "You already have an active mentor request."},
	ErrChangeRequestPending: {Status: http.StatusConflict, Message: "A mentor change request is already pending for this ticket."},
	ErrInvalid:              {Status: http.StatusUnprocessableEntity},
}

func writeDomainError(w http.ResponseWriter, err error) {
	httputil.WriteDomainError(w, err, domainErrors, "Something went wrong.")
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
