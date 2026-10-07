package legal

import (
	"net/http"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/authevents"
	"github.com/mindforge/backend/internal/httputil"
)

type Handler struct {
	service *Service
}

var domainErrors = map[error]httputil.ErrSpec{
	ErrInvalid: {Status: http.StatusUnprocessableEntity},
}

var writeDomainError = httputil.DomainErrorWriter(domainErrors, "Something went wrong.")

// HandleStatus reports which legal documents the caller still needs to
// (re-)accept.
func (h *Handler) HandleStatus(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	needed, err := h.service.Status(r.Context(), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"needs_acceptance": needed})
}

// HandleAccept records the caller's consent to a document's current
// version. Body: {"doc_type": "..."}.
func (h *Handler) HandleAccept(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		DocType string `json:"doc_type"`
	}
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	ip := authevents.TruncateIP(r.RemoteAddr)
	acceptance, err := h.service.Accept(r.Context(), claims.UserID, req.DocType, &ip)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, acceptance)
}
