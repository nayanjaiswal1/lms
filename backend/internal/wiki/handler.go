package wiki

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

type Handler struct {
	service *Service
}

func newHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// ─── shared helpers ───────────────────────────────────────────────────────────

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

func writeDomainError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrNotFound), errors.Is(err, ErrCourseNotFound):
		httputil.WriteError(w, http.StatusNotFound, "Not found.")
	case errors.Is(err, ErrForbidden), errors.Is(err, ErrTemplateInvalid):
		httputil.WriteError(w, http.StatusForbidden, "You do not have permission to perform this action.")
	case errors.Is(err, ErrValidation):
		httputil.WriteError(w, http.StatusUnprocessableEntity, "Invalid request.")
	default:
		httputil.WriteError(w, http.StatusInternalServerError, "Something went wrong.")
	}
}

func optionalQueryParam(r *http.Request, key string) *string {
	v := r.URL.Query().Get(key)
	if v == "" {
		return nil
	}
	return &v
}

// ─── Spaces ───────────────────────────────────────────────────────────────────

func (h *Handler) ListSpaces(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	spaces, err := h.service.ListSpaces(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, spaces)
}

func (h *Handler) CreateSpace(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req CreateSpaceRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	sp, err := h.service.CreateSpace(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, sp)
}

func (h *Handler) GetSpace(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	slug := chi.URLParam(r, "slug")
	sp, err := h.service.GetSpace(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, slug)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, sp)
}

func (h *Handler) UpdateSpace(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req UpdateSpaceRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	sp, err := h.service.UpdateSpace(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, chi.URLParam(r, "id"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, sp)
}

func (h *Handler) DeleteSpace(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.DeleteSpace(r.Context(), claims.OrgID, claims.OrgRole, chi.URLParam(r, "id")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"deleted": true})
}

// ─── Page tree ────────────────────────────────────────────────────────────────

func (h *Handler) GetPageTree(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	tree, err := h.service.GetPageTree(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, chi.URLParam(r, "spaceId"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, tree)
}

// ─── Pages ────────────────────────────────────────────────────────────────────

func (h *Handler) CreatePage(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req CreatePageRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	p, err := h.service.CreatePage(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, chi.URLParam(r, "spaceId"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, p)
}

func (h *Handler) GetPage(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	p, err := h.service.GetPage(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, chi.URLParam(r, "id"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, p)
}

func (h *Handler) UpdatePage(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req UpdatePageRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	p, err := h.service.UpdatePage(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, chi.URLParam(r, "id"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, p)
}

func (h *Handler) DeletePage(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.DeletePage(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, chi.URLParam(r, "id")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"deleted": true})
}

func (h *Handler) MovePage(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req MovePageRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	p, err := h.service.MovePage(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, chi.URLParam(r, "id"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, p)
}

// ─── Version history ─────────────────────────────────────────────────────────

func (h *Handler) ListVersions(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	versions, err := h.service.ListVersions(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, chi.URLParam(r, "id"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, versions)
}

func (h *Handler) GetVersion(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	version, err := strconv.Atoi(chi.URLParam(r, "version"))
	if err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid version number.")
		return
	}
	v, err := h.service.GetVersion(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, chi.URLParam(r, "id"), version)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, v)
}

func (h *Handler) RestoreVersion(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	version, err := strconv.Atoi(chi.URLParam(r, "version"))
	if err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid version number.")
		return
	}
	p, err := h.service.RestoreVersion(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, chi.URLParam(r, "id"), version)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, p)
}

// ─── Comments ─────────────────────────────────────────────────────────────────

func (h *Handler) ListComments(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	comments, err := h.service.ListComments(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, chi.URLParam(r, "id"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, comments)
}

func (h *Handler) CreateComment(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req CreateCommentRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	c, err := h.service.CreateComment(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, chi.URLParam(r, "id"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, c)
}

func (h *Handler) UpdateComment(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req UpdateCommentRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	c, err := h.service.UpdateComment(r.Context(), claims.UserID, claims.OrgRole, chi.URLParam(r, "id"), req.Content)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, c)
}

func (h *Handler) DeleteComment(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.DeleteComment(r.Context(), claims.UserID, claims.OrgRole, chi.URLParam(r, "id")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"deleted": true})
}

// ─── Templates ────────────────────────────────────────────────────────────────

func (h *Handler) ListTemplates(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	templates, err := h.service.ListTemplates(r.Context(), claims.OrgID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, templates)
}

func (h *Handler) CreateTemplate(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req CreateTemplateRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	t, err := h.service.CreateTemplate(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, t)
}

func (h *Handler) DeleteTemplate(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.DeleteTemplate(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, chi.URLParam(r, "id")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"deleted": true})
}

// ─── Search ───────────────────────────────────────────────────────────────────

func (h *Handler) Search(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	results, err := h.service.Search(r.Context(), claims.OrgID, r.URL.Query().Get("q"), optionalQueryParam(r, "space"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, results)
}
