package workspace

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"net"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/ratelimit"
)

// clientIP extracts the client IP from r.RemoteAddr, stripping the port —
// the same shape as middleware.clientIP (unexported there). RealIP has
// already replaced RemoteAddr with the forwarded client address when the
// request arrived through a trusted proxy, so this is the real client IP,
// never an attacker-chosen header value.
func clientIP(r *http.Request) string {
	if host, _, err := net.SplitHostPort(r.RemoteAddr); err == nil {
		return host
	}
	return strings.Trim(r.RemoteAddr, "[]")
}

// hashEmail is the rate-limit key for InterestPerEmailDay — never the raw
// address (02 §4.3).
func hashEmail(email string) string {
	sum := sha256.Sum256([]byte(strings.ToLower(strings.TrimSpace(email))))
	return hex.EncodeToString(sum[:])
}

// rateLimited checks key and, if exhausted, writes the 429 + Retry-After
// response and returns true so the caller can `if h.rateLimited(...) { return }`.
func (h *Handler) rateLimited(w http.ResponseWriter, r *http.Request, key string, max int, window time.Duration) bool {
	allowed, retryAfter := h.limiter.Allow(r.Context(), key, max, window)
	if allowed {
		return false
	}
	w.Header().Set("Retry-After", strconv.Itoa(ratelimit.RetryAfterSeconds(retryAfter)))
	httputil.WriteError(w, http.StatusTooManyRequests, "Too many requests. Please try again later.")
	return true
}

// publicHeaders sets the no-index/no-cache headers every public workspace
// route must carry (02 §4.2).
func publicHeaders(w http.ResponseWriter) {
	w.Header().Set("Referrer-Policy", "no-referrer")
	w.Header().Set("X-Robots-Tag", "noindex")
	w.Header().Set("Cache-Control", "no-store")
}

// GetPublicProject is GET /api/public/workspaces/{shareToken} — no auth. An
// unknown/draft/closed/rotated token gets the exact same 404 body as any
// other not-shown case, at the same rate limit, so a scanner can't
// distinguish "token never existed" from "token exists but isn't public".
func (h *Handler) GetPublicProject(w http.ResponseWriter, r *http.Request) {
	if h.rateLimited(w, r, "rl:pw:view:ip:"+clientIP(r), h.cfg.Workspace.PublicViewPerIPMinute, time.Minute) {
		return
	}
	publicHeaders(w)

	p, err := h.service.GetPublicProject(r.Context(), chi.URLParam(r, "shareToken"))
	if err != nil {
		httputil.WriteError(w, http.StatusNotFound, "Not found.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, p)
}

// SubmitInterest is POST /api/public/workspaces/{shareToken}/interest — no
// auth. Every accepted-shape body gets the same 202 (D14); only a malformed
// body (empty name, bad email, oversize fields) gets a 422, so the form
// itself can still show real validation errors.
func (h *Handler) SubmitInterest(w http.ResponseWriter, r *http.Request) {
	publicHeaders(w)
	r.Body = http.MaxBytesReader(w, r.Body, InterestBodyMaxBytes)

	var req SubmitInterestRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}

	token := chi.URLParam(r, "shareToken")
	if h.rateLimited(w, r, "rl:pw:int:ip:"+clientIP(r), h.cfg.Workspace.InterestPerIPHour, time.Hour) {
		return
	}
	if req.Email != "" && h.rateLimited(w, r, "rl:pw:int:email:"+hashEmail(req.Email), h.cfg.Workspace.InterestPerEmailDay, 24*time.Hour) {
		return
	}
	if h.rateLimited(w, r, "rl:pw:int:proj:"+token, h.cfg.Workspace.InterestPerProjectDay, 24*time.Hour) {
		return
	}

	if err := h.service.SubmitInterest(r.Context(), token, req); err != nil {
		if errors.Is(err, ErrNotFound) {
			httputil.WriteError(w, http.StatusNotFound, "Not found.")
			return
		}
		writeDomainError(w, err) // *FieldError -> 422
		return
	}
	httputil.WriteJSON(w, http.StatusAccepted, map[string]string{"message": InterestAckMessage})
}

// ListInterests is GET /api/workspaces/{workspaceID}/interests (manager+).
func (h *Handler) ListInterests(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	status := httputil.QueryStr(r, "status")
	cursor := httputil.QueryStr(r, "cursor")
	limit := httputil.QueryIntPositive(r, "limit", PageSizeDefault)
	page, err := h.service.ListInterests(r.Context(), pc, status, cursor, limit)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, page)
}

// ReviewInterest is PATCH .../interests/{interestID} (manager+).
func (h *Handler) ReviewInterest(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req ReviewInterestRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	result, err := h.service.ReviewInterest(r.Context(), pc, chi.URLParam(r, "interestID"), req.Decision)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, result)
}

// RankInterest is POST .../interests/{interestID}/rank (manager+).
func (h *Handler) RankInterest(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	i, err := h.service.RankInterest(r.Context(), pc, chi.URLParam(r, "interestID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, i)
}

// Discover is GET /api/workspaces/discover — open recruiting workspaces in
// the caller's org they are not yet a member of.
func (h *Handler) Discover(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	page, err := h.service.ListDiscoverable(r.Context(), claims.OrgID, claims.UserID,
		httputil.QueryStr(r, "cursor"), httputil.QueryIntPositive(r, "limit", PageSizeDefault))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, page)
}

// ApplyInterest is POST /api/workspaces/{id}/interest — logged-in apply.
// Body is optional (skills, portfolio_url, message); name/email come from the
// user row.
func (h *Handler) ApplyInterest(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, InterestBodyMaxBytes)
	var req SubmitInterestRequest
	if !httputil.DecodeJSONAllowEmpty(w, r, &req) {
		return
	}
	id := chi.URLParam(r, "workspaceID")
	if h.rateLimited(w, r, "rl:pw:int:user:"+claims.UserID, h.cfg.Workspace.InterestPerIPHour, time.Hour) {
		return
	}
	if err := h.service.ApplyInterest(r.Context(), claims.OrgID, claims.UserID, id, req); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, map[string]string{"message": InterestAckMessage})
}

// WithdrawInterest is DELETE /api/workspaces/{id}/interest.
func (h *Handler) WithdrawInterest(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.WithdrawInterest(r.Context(), claims.OrgID, claims.UserID, chi.URLParam(r, "workspaceID")); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ListMyInterests is GET /api/my/workspace-interests.
func (h *Handler) ListMyInterests(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	items, err := h.service.ListMyInterests(r.Context(), claims.OrgID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"items": items})
}
