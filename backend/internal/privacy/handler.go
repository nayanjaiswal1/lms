package privacy

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/authevents"
	"github.com/mindforge/backend/internal/httputil"
)

type Handler struct {
	service *Service
	pool    *pgxpool.Pool
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
	authevents.Emit(r.Context(), h.pool, r, claims.UserID, authevents.DataExport)
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
	if !httputil.DecodeJSON(w, r, &req) {
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
	authevents.Emit(r.Context(), h.pool, r, claims.UserID, authevents.AccountDeletion)
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Your account has been deleted."})
}

// HandleGetSettings returns the caller's AI consent and nominee.
func (h *Handler) HandleGetSettings(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	s, err := h.service.repo.GetSettings(r.Context(), claims.UserID)
	if err != nil {
		slog.Error("privacy: get settings", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not load your privacy settings.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, s)
}

// HandleSetAIConsent records or withdraws consent. Body: {"consent": bool}.
func (h *Handler) HandleSetAIConsent(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Consent bool `json:"consent"`
	}
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	if err := h.service.repo.SetAIConsent(r.Context(), claims.UserID, req.Consent); err != nil {
		slog.Error("privacy: set ai consent", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not save your choice.")
		return
	}
	h.HandleGetSettings(w, r)
}

// HandleSetNominee stores or clears the nominee. Body: {"nominee": {...}|null}.
func (h *Handler) HandleSetNominee(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Nominee *Nominee `json:"nominee"`
	}
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	nominee, err := normalizeNominee(req.Nominee)
	if err != nil {
		httputil.WriteError(w, http.StatusUnprocessableEntity, err.Error())
		return
	}
	if err := h.service.repo.SetNominee(r.Context(), claims.UserID, nominee); err != nil {
		slog.Error("privacy: set nominee", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not save your nominee.")
		return
	}
	h.HandleGetSettings(w, r)
}
