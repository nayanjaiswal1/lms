package legal

import (
	"encoding/json"
	"fmt"
	"net"
	"net/http"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

type Handler struct {
	service *Service
}

var domainErrors = map[error]httputil.ErrSpec{
	ErrInvalid: {Status: http.StatusUnprocessableEntity},
}

func writeDomainError(w http.ResponseWriter, err error) {
	httputil.WriteDomainError(w, err, domainErrors, "Something went wrong.")
}

// firstThreeOctets mirrors internal/auth's helper of the same name — stored
// IPs are truncated platform-wide, not full addresses, to minimize retained
// PII (see refresh_tokens.ip in docs/auth.md).
func firstThreeOctets(remoteAddr string) string {
	host := remoteAddr
	if h, _, err := net.SplitHostPort(remoteAddr); err == nil {
		host = h
	}
	ip := net.ParseIP(host)
	if ip == nil {
		return host
	}
	if v4 := ip.To4(); v4 != nil {
		return fmt.Sprintf("%d.%d.%d", v4[0], v4[1], v4[2])
	}
	return ip.Mask(net.CIDRMask(48, 128)).String()
}

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
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}
	ip := firstThreeOctets(r.RemoteAddr)
	acceptance, err := h.service.Accept(r.Context(), claims.UserID, req.DocType, &ip)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, acceptance)
}
