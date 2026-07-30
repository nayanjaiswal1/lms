package gitlab

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/mindforge/backend/internal/auth"
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

// writeDomainError maps domain/service errors to HTTP responses.
func writeDomainError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrNotFound):
		httputil.WriteError(w, http.StatusNotFound, "GitLab is not connected for your organization yet.")
	case errors.Is(err, ErrNoOAuthApp):
		httputil.WriteError(w, http.StatusConflict, "Your organization's GitLab installation has no OAuth application configured yet — ask an admin to add one.")
	case errors.Is(err, ErrStateExpired):
		httputil.WriteError(w, http.StatusBadRequest, "This connection request expired. Please try again.")
	case errors.Is(err, ErrAlreadyOnTeam):
		httputil.WriteError(w, http.StatusConflict, "This student is already on a team for this assignment.")
	case errors.Is(err, ErrConflict):
		httputil.WriteError(w, http.StatusConflict, "This action conflicts with the current state.")
	case errors.Is(err, ErrInsufficientApprovals):
		httputil.WriteError(w, http.StatusConflict, err.Error())
	case errors.Is(err, ErrCannotDeleteDefault):
		httputil.WriteError(w, http.StatusConflict, "This is the default GitLab connection. Set another one as default before deleting it.")
	case errors.Is(err, ErrOverrideNotAllowed):
		httputil.WriteError(w, http.StatusForbidden, "This organization does not allow per-project GitLab overrides.")
	default:
		httputil.WriteError(w, http.StatusInternalServerError, "Something went wrong. Please try again.")
	}
}
