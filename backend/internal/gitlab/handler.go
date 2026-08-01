package gitlab

import (
	"encoding/json"
	"net/http"

	"github.com/mindforge/backend/internal/httputil"
)

// Handler exposes the gitlab domain over HTTP. It owns the service.
type Handler struct {
	service *Service
}

// NewHandler builds the gitlab HTTP handler.
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// ─── shared helpers ──────────────────────────────────────────────────────────

// ctxClaims pulls the authenticated claims or writes 401 and returns false.
func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
}

// writeDomainError maps domain/service errors to HTTP responses.
var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound:              {Status: http.StatusNotFound, Message: "GitLab is not connected for your organization yet."},
	ErrNoOAuthApp:            {Status: http.StatusConflict, Message: "Your organization's GitLab installation has no OAuth application configured yet — ask an admin to add one."},
	ErrStateExpired:          {Status: http.StatusBadRequest, Message: "This connection request expired. Please try again."},
	ErrAlreadyOnTeam:         {Status: http.StatusConflict, Message: "This student is already on a team for this assignment."},
	ErrConflict:              {Status: http.StatusConflict, Message: "This action conflicts with the current state."},
	ErrInsufficientApprovals: {Status: http.StatusConflict},
	ErrCannotDeleteDefault:   {Status: http.StatusConflict, Message: "This is the default GitLab connection. Set another one as default before deleting it."},
	ErrOverrideNotAllowed:    {Status: http.StatusForbidden, Message: "This organization does not allow per-project GitLab overrides."},
}

func writeDomainError(w http.ResponseWriter, err error) {
	httputil.WriteDomainError(w, err, domainErrors, "Something went wrong. Please try again.")
}
