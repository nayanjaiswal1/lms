package workspace

import (
	"net/http"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// projectCtxOr500 fetches the ProjectCtx RequireProjectRole should have set,
// or writes a 500 if it's missing (a route wired without the middleware).
func projectCtxOr500(w http.ResponseWriter, r *http.Request) (*ProjectCtx, bool) {
	pc, ok := GetProjectCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusInternalServerError, "Internal server error.")
		return nil, false
	}
	return pc, true
}

func (h *Handler) CreateProject(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req CreateProjectRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	p, err := h.service.CreateProject(r.Context(), claims.OrgID, claims.UserID, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, p)
}

func (h *Handler) ListProjects(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	cursor := httputil.QueryStr(r, "cursor")
	limit := httputil.QueryIntPositive(r, "limit", PageSizeDefault)
	page, err := h.service.ListProjects(r.Context(), claims.OrgID, claims.UserID, cursor, limit)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, page)
}

func (h *Handler) GetProject(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	detail, err := h.service.GetProject(r.Context(), pc)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	maskShareToken(&detail.Project, pc)
	httputil.WriteJSON(w, http.StatusOK, detail)
}

func (h *Handler) UpdateProject(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req UpdateProjectRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	p, err := h.service.UpdateProject(r.Context(), pc, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, p)
}

func (h *Handler) SetProjectStatus(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req SetStatusRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	p, err := h.service.SetProjectStatus(r.Context(), pc, req.Status)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, p)
}

func (h *Handler) RotateShareToken(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	token, err := h.service.RotateShareToken(r.Context(), pc)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"share_token": token})
}

func (h *Handler) TransferOwner(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req TransferOwnerRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	if err := h.service.TransferOwner(r.Context(), pc, req.UserID); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{})
}

func (h *Handler) GetRequirement(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	view, err := h.service.GetRequirement(r.Context(), pc)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, view)
}

func (h *Handler) UpdateRequirement(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req struct {
		Requirement string `json:"requirement"`
	}
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	view, err := h.service.UpdateRequirement(r.Context(), pc, req.Requirement)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, view)
}
