package wiki

import (
	"archive/zip"
	"bytes"
	"io"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/middleware"
)

// maxOKFBodyBytes caps an OKF markdown PUT body — a wiki page is prose, not
// a bulk upload; this is generous headroom over any realistic page size.
const maxOKFBodyBytes = 5 << 20 // 5 MiB

type Handler struct {
	service *Service
	pool    *pgxpool.Pool
}

func newHandler(service *Service, pool *pgxpool.Pool) *Handler {
	return &Handler{service: service, pool: pool}
}

// requireMember is auth.RequireClaims with the org role re-read from the
// database. The JWT's OrgRole is minted at sign-in and outlives a demotion or
// removal, and every wiki permission check keys off it, so the live role
// replaces it and a user who is no longer an active member is refused.
func (h *Handler) requireMember(w http.ResponseWriter, r *http.Request) (*auth.Claims, bool) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return nil, false
	}
	role, member := middleware.LiveOrgRole(r.Context(), h.pool, claims.UserID, claims.OrgID)
	if !member {
		httputil.WriteError(w, http.StatusForbidden, "You are not a member of this organization.")
		return nil, false
	}
	live := *claims
	live.OrgRole = role
	return &live, true
}

// ─── shared helpers ───────────────────────────────────────────────────────────

var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound:        {Status: http.StatusNotFound, Message: "Not found."},
	ErrCourseNotFound:  {Status: http.StatusNotFound, Message: "Not found."},
	ErrForbidden:       {Status: http.StatusForbidden, Message: "You do not have permission to perform this action."},
	ErrTemplateInvalid: {Status: http.StatusForbidden, Message: "You do not have permission to perform this action."},
	ErrValidation:      {Status: http.StatusUnprocessableEntity, Message: "Invalid request."},
}

var writeDomainError = httputil.DomainErrorWriter(domainErrors, "Something went wrong.")

func optionalQueryParam(r *http.Request, key string) *string {
	v := r.URL.Query().Get(key)
	if v == "" {
		return nil
	}
	return &v
}

// ─── Spaces ───────────────────────────────────────────────────────────────────

func (h *Handler) ListSpaces(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.requireMember(w, r)
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
	claims, ok := h.requireMember(w, r)
	if !ok {
		return
	}
	var req CreateSpaceRequest
	if !httputil.DecodeJSON(w, r, &req) {
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
	claims, ok := h.requireMember(w, r)
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
	claims, ok := h.requireMember(w, r)
	if !ok {
		return
	}
	var req UpdateSpaceRequest
	if !httputil.DecodeJSON(w, r, &req) {
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
	claims, ok := h.requireMember(w, r)
	if !ok {
		return
	}
	if err := h.service.DeleteSpace(r.Context(), claims.OrgID, claims.OrgRole, chi.URLParam(r, "id")); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ─── Page tree ────────────────────────────────────────────────────────────────

func (h *Handler) GetPageTree(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.requireMember(w, r)
	if !ok {
		return
	}
	tree, err := h.service.GetPageTree(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, chi.URLParam(r, "spaceID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, tree)
}

// ─── Pages ────────────────────────────────────────────────────────────────────

func (h *Handler) CreatePage(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.requireMember(w, r)
	if !ok {
		return
	}
	var req CreatePageRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	p, err := h.service.CreatePage(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, chi.URLParam(r, "spaceID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, p)
}

func (h *Handler) GetPage(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.requireMember(w, r)
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
	claims, ok := h.requireMember(w, r)
	if !ok {
		return
	}
	var req UpdatePageRequest
	if !httputil.DecodeJSON(w, r, &req) {
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
	claims, ok := h.requireMember(w, r)
	if !ok {
		return
	}
	if err := h.service.DeletePage(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, chi.URLParam(r, "id")); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ─── Version history ─────────────────────────────────────────────────────────

func (h *Handler) ListVersions(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.requireMember(w, r)
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
	claims, ok := h.requireMember(w, r)
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
	claims, ok := h.requireMember(w, r)
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
	claims, ok := h.requireMember(w, r)
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
	claims, ok := h.requireMember(w, r)
	if !ok {
		return
	}
	var req CreateCommentRequest
	if !httputil.DecodeJSON(w, r, &req) {
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
	claims, ok := h.requireMember(w, r)
	if !ok {
		return
	}
	var req UpdateCommentRequest
	if !httputil.DecodeJSON(w, r, &req) {
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
	claims, ok := h.requireMember(w, r)
	if !ok {
		return
	}
	if err := h.service.DeleteComment(r.Context(), claims.UserID, claims.OrgRole, chi.URLParam(r, "id")); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ─── Templates ────────────────────────────────────────────────────────────────

func (h *Handler) ListTemplates(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.requireMember(w, r)
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
	claims, ok := h.requireMember(w, r)
	if !ok {
		return
	}
	var req CreateTemplateRequest
	if !httputil.DecodeJSON(w, r, &req) {
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
	claims, ok := h.requireMember(w, r)
	if !ok {
		return
	}
	if err := h.service.DeleteTemplate(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, chi.URLParam(r, "id")); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ─── OKF export/import ────────────────────────────────────────────────────────

func (h *Handler) GetPageOKF(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.requireMember(w, r)
	if !ok {
		return
	}
	md, err := h.service.GetPageOKF(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, chi.URLParam(r, "id"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	w.Header().Set("Content-Type", "text/markdown; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(md))
}

func (h *Handler) UpdatePageOKF(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.requireMember(w, r)
	if !ok {
		return
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, maxOKFBodyBytes))
	if err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Could not read request body.")
		return
	}
	p, err := h.service.UpdatePageOKF(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, chi.URLParam(r, "id"), string(body))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, p)
}

func (h *Handler) GetSpaceOKF(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.requireMember(w, r)
	if !ok {
		return
	}
	slug := chi.URLParam(r, "slug")
	files, err := h.service.GetSpaceOKFBundle(r.Context(), claims.OrgID, claims.UserID, claims.OrgRole, slug)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	for name, content := range files {
		fw, err := zw.Create(name)
		if err != nil {
			httputil.WriteError(w, http.StatusInternalServerError, "Could not build bundle.")
			return
		}
		if _, err := fw.Write([]byte(content)); err != nil {
			httputil.WriteError(w, http.StatusInternalServerError, "Could not build bundle.")
			return
		}
	}
	if err := zw.Close(); err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Could not build bundle.")
		return
	}

	w.Header().Set("Content-Type", "application/zip")
	w.Header().Set("Content-Disposition", `attachment; filename="`+slug+`-okf.zip"`)
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(buf.Bytes())
}

// ─── Search ───────────────────────────────────────────────────────────────────

func (h *Handler) Search(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.requireMember(w, r)
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
