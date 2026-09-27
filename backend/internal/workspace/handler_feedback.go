package workspace

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/httputil"
)

// GetFeedback is GET …/feedback.
func (h *Handler) GetFeedback(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	view, err := h.service.GetFeedback(r.Context(), pc)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, view)
}

// SubmitPeerFeedback is POST …/feedback.
func (h *Handler) SubmitPeerFeedback(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req PeerFeedbackRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	if err := h.service.SubmitPeerFeedback(r.Context(), pc, req); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{})
}

// GetMemberReport is GET …/members/{userID}/report.
func (h *Handler) GetMemberReport(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	report, err := h.service.BuildMemberReport(r.Context(), pc, chi.URLParam(r, "userID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, report)
}

// IssueCertificate is POST …/certificates.
func (h *Handler) IssueCertificate(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req IssueCertificateRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	report, err := h.service.IssueCertificate(r.Context(), pc, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, report)
}

// SetShowcaseOptIn is PUT …/membership/showcase.
func (h *Handler) SetShowcaseOptIn(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req struct {
		OptIn bool `json:"opt_in"`
	}
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	if err := h.service.SetShowcaseOptIn(r.Context(), pc, req.OptIn); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{})
}
