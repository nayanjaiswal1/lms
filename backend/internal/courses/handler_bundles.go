package courses

import (
	"net/http"

	"github.com/google/uuid"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/middleware"
)

// maxBundleCourses caps one bundle's course list — a bundle is a curated
// path, not a catalog dump, and the cap keeps the enroll-in-all insert small.
const maxBundleCourses = 50

type bundleReq struct {
	Title       string  `json:"title"`
	Description *string `json:"description"`
	CoverURL    *string `json:"cover_url"`
	Status      string  `json:"status"`
}

// validate checks a create/update body and defaults an empty status to draft.
func (req *bundleReq) validate() map[string]string {
	fields := map[string]string{}
	if len(req.Title) < titleMinLen || len(req.Title) > titleMaxLen {
		fields["title"] = "Title must be 3–200 characters."
	}
	if req.Description != nil && len(*req.Description) > descriptionMaxLen {
		fields["description"] = "Description must be at most 2000 characters."
	}
	if req.Status == "" {
		req.Status = BundleStatusDraft
	}
	if req.Status != BundleStatusDraft && req.Status != BundleStatusPublished {
		fields["status"] = "Status must be draft or published."
	}
	return fields
}

// ─── Instructor ───────────────────────────────────────────────────────────────

func (h *Handler) CreateBundle(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req bundleReq
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	if fields := req.validate(); len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}
	created, err := h.repo.CreateBundle(r.Context(), Bundle{
		OrgID: claims.OrgID, CreatorID: claims.UserID, Title: req.Title, Slug: Slugify(req.Title),
		Description: req.Description, CoverURL: req.CoverURL, Status: req.Status,
	})
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, created)
}

func (h *Handler) UpdateBundle(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req bundleReq
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	if fields := req.validate(); len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}
	updated, err := h.repo.UpdateBundle(r.Context(), claims.OrgID, Bundle{
		ID: httputil.URLParam(r, "bundleID"), Title: req.Title,
		Description: req.Description, CoverURL: req.CoverURL, Status: req.Status,
	})
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, updated)
}

func (h *Handler) DeleteBundle(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	if err := h.repo.DeleteBundle(r.Context(), claims.OrgID, httputil.URLParam(r, "bundleID")); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// SetBundleCourses replaces the bundle's ordered course list in one call.
func (h *Handler) SetBundleCourses(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		CourseIDs []string `json:"course_ids"`
	}
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	if req.CourseIDs == nil {
		req.CourseIDs = []string{}
	}
	if len(req.CourseIDs) > maxBundleCourses {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"course_ids": "A bundle can hold at most 50 courses."})
		return
	}
	seen := make(map[string]bool, len(req.CourseIDs))
	for _, id := range req.CourseIDs {
		if _, err := uuid.Parse(id); err != nil || seen[id] {
			httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"course_ids": "Course ids must be distinct, valid ids."})
			return
		}
		seen[id] = true
	}
	bundleID := httputil.URLParam(r, "bundleID")
	if err := h.repo.SetBundleCourses(r.Context(), claims.OrgID, bundleID, req.CourseIDs); err != nil {
		writeDomainError(w, err)
		return
	}
	d, err := h.repo.GetBundleDetail(r.Context(), claims.OrgID, claims.UserID, bundleID, "", false)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, d)
}

// ListManagedBundles lists every bundle in the org, drafts included.
// ─── All authenticated users ─────────────────────────────────────────────────

// includeDrafts reads ?include_drafts=true — the editor's view, drafts and
// unpublished courses included — which only instructors+ may ask for.
// Reports false after writing 403 when the caller may not.
func (h *Handler) includeDrafts(w http.ResponseWriter, r *http.Request, claims *auth.Claims) (drafts, ok bool) {
	if r.URL.Query().Get("include_drafts") != "true" {
		return false, true
	}
	if !middleware.HasLiveOrgRole(r.Context(), h.repo.Pool(), claims.UserID, claims.OrgID,
		middleware.RoleOwner, middleware.RoleAdmin, middleware.RoleInstructor) {
		httputil.WriteError(w, http.StatusForbidden, "Only instructors can see draft bundles.")
		return false, false
	}
	return true, true
}

// ListBundles handles GET /api/bundles[?include_drafts=true].
func (h *Handler) ListBundles(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	drafts, ok := h.includeDrafts(w, r, claims)
	if !ok {
		return
	}
	bundles, err := h.repo.ListBundles(r.Context(), claims.OrgID, !drafts)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"bundles": bundles})
}

// GetBundleBySlug handles GET /api/bundles/by-slug/{slug}[?include_drafts=true].
func (h *Handler) GetBundleBySlug(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	drafts, ok := h.includeDrafts(w, r, claims)
	if !ok {
		return
	}
	d, err := h.repo.GetBundleDetail(r.Context(), claims.OrgID, claims.UserID, "", httputil.URLParam(r, "slug"), !drafts)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, d)
}

func (h *Handler) EnrollInBundle(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	res, err := h.repo.EnrollInBundle(r.Context(), claims.OrgID, claims.UserID, httputil.URLParam(r, "bundleID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, res)
}
