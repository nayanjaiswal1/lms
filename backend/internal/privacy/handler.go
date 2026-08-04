package privacy

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

type Handler struct {
	service *Service
}

// HandleExport returns the caller's full exportable data bundle as a JSON
// download.
func (h *Handler) HandleExport(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	data, err := h.service.Export(r.Context(), claims.UserID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Could not export your data.")
		return
	}
	w.Header().Set("Content-Disposition", `attachment; filename="mindforge-data-export.json"`)
	httputil.WriteJSON(w, http.StatusOK, data)
}

// HandleDeleteAccount anonymizes the caller's account and ends every
// session. Body: {"password": "..."} — required only for password-based
// accounts, ignored (may be omitted) for social/passkey-only accounts.
func (h *Handler) HandleDeleteAccount(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}
	if err := h.service.DeleteAccount(r.Context(), claims.UserID, req.Password); err != nil {
		if errors.Is(err, ErrWrongPassword) {
			httputil.WriteError(w, http.StatusUnprocessableEntity, "Incorrect password.")
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "Could not delete your account.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Your account has been deleted."})
}
