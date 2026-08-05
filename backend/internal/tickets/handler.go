package tickets

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/httputil"
)

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

// canManage reports whether callerID holds kind's manage permission in orgID.
func (h *Handler) canManage(r *http.Request, userID, orgID, kind string) (bool, error) {
	return h.authzSvc.HasPermission(r.Context(), userID, orgID, ManagePermission[kind])
}

// canViewQueue reports whether callerID holds kind's queue-visibility
// permission in orgID.
func (h *Handler) canViewQueue(r *http.Request, userID, orgID, kind string) (bool, error) {
	return h.authzSvc.HasPermission(r.Context(), userID, orgID, QueuePermission[kind])
}

// CreateSupportTicket lets any authenticated org member raise a new support
// ticket. Body: {"subject": "...", "message": "..."}.
func (h *Handler) CreateSupportTicket(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Subject string `json:"subject"`
		Message string `json:"message"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	ticket, err := h.service.CreateSupportTicket(r.Context(), claims.OrgID, claims.UserID, req.Subject, req.Message)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, ticket)
}

// ListMine returns the authenticated caller's own tickets, optionally
// filtered by ?kind=.
func (h *Handler) ListMine(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	tickets, err := h.service.ListMine(r.Context(), claims.OrgID, claims.UserID, queryStrPtr(r, "kind"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"tickets": tickets})
}

// ListQueue returns every ticket of the required ?kind= in the org,
// optionally filtered by ?status= and ?mine=true (assigned to the caller).
// Requires kind's QueuePermission.
func (h *Handler) ListQueue(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	kind := r.URL.Query().Get("kind")
	if kind != KindSupport && kind != KindMentorship {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"kind": "kind must be support or mentorship."})
		return
	}
	allowed, err := h.canViewQueue(r, claims.UserID, claims.OrgID, kind)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Permission check failed.")
		return
	}
	if !allowed {
		httputil.WriteError(w, http.StatusForbidden, "You do not have permission to do that.")
		return
	}
	var assignedTo *string
	if r.URL.Query().Get("mine") == "true" {
		assignedTo = &claims.UserID
	}
	tickets, err := h.service.ListQueue(r.Context(), claims.OrgID, kind, queryStrPtr(r, "status"), assignedTo)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"tickets": tickets})
}

// Get returns a single ticket's detail plus its full reply thread in one
// response — allowed for its own requester, its current assignee, or a
// caller holding its kind's manage permission.
func (h *Handler) Get(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	ticketID := urlParam(r, "ticketID")
	kind, err := h.service.Kind(r.Context(), claims.OrgID, ticketID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	canManage, err := h.canManage(r, claims.UserID, claims.OrgID, kind)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Permission check failed.")
		return
	}
	detail, err := h.service.Get(r.Context(), claims.OrgID, ticketID, claims.UserID, canManage)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, detail)
}

// ListMessages returns a ticket's full reply thread — allowed for its own
// requester, its current assignee, or a caller holding its kind's manage
// permission.
func (h *Handler) ListMessages(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	ticketID := urlParam(r, "ticketID")
	kind, err := h.service.Kind(r.Context(), claims.OrgID, ticketID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	canManage, err := h.canManage(r, claims.UserID, claims.OrgID, kind)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Permission check failed.")
		return
	}
	messages, err := h.service.ListMessages(r.Context(), claims.OrgID, ticketID, claims.UserID, canManage)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"messages": messages})
}

// SendMessage posts a reply on a ticket's thread — allowed for its own
// requester, its current assignee, or a caller holding its kind's manage
// permission. Body: {"body": "..."}.
func (h *Handler) SendMessage(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Body string `json:"body"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	ticketID := urlParam(r, "ticketID")
	kind, err := h.service.Kind(r.Context(), claims.OrgID, ticketID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	canManage, err := h.canManage(r, claims.UserID, claims.OrgID, kind)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Permission check failed.")
		return
	}
	message, err := h.service.SendMessage(r.Context(), claims.OrgID, ticketID, claims.UserID, req.Body, canManage)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, message)
}

// SetStatus changes a support ticket's status. Requires support.manage.
// Body: {"status": "..."}.
func (h *Handler) SetStatus(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Status string `json:"status"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	ticketID := urlParam(r, "ticketID")
	kind, err := h.service.Kind(r.Context(), claims.OrgID, ticketID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	canManage, err := h.canManage(r, claims.UserID, claims.OrgID, kind)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Permission check failed.")
		return
	}
	if !canManage {
		httputil.WriteError(w, http.StatusForbidden, "You do not have permission to do that.")
		return
	}
	ticket, err := h.service.SetStatus(r.Context(), claims.OrgID, ticketID, req.Status, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, ticket)
}

// SetProperties sets a support ticket's category and priority — the staff
// triage step. Requires support.manage. Body: {"category": "...", "priority": "..."}.
func (h *Handler) SetProperties(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Category string `json:"category"`
		Priority string `json:"priority"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	ticketID := urlParam(r, "ticketID")
	kind, err := h.service.Kind(r.Context(), claims.OrgID, ticketID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	canManage, err := h.canManage(r, claims.UserID, claims.OrgID, kind)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Permission check failed.")
		return
	}
	if !canManage {
		httputil.WriteError(w, http.StatusForbidden, "You do not have permission to do that.")
		return
	}
	ticket, err := h.service.SetProperties(r.Context(), claims.OrgID, ticketID, req.Category, req.Priority)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, ticket)
}
