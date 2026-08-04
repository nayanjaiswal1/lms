package support

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/httputil"
)

// PermissionManage gates the staff queue (view every ticket, reply, change
// status) — mirrors backend/db/migrations/021_support_tickets.sql.
const PermissionManage = "support.manage"

type Handler struct {
	service  *Service
	authzSvc *authz.Service
}

var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound:  {Status: http.StatusNotFound, Message: "Not found."},
	ErrForbidden: {Status: http.StatusForbidden, Message: "You do not have permission to do that."},
	ErrInvalid:   {Status: http.StatusUnprocessableEntity},
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
