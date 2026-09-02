package courses

import (
	"encoding/json"
	"net/http"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// decodeOptionalJSON decodes an optional JSON body (e.g. {"review_note": "..."})
// without writing an error response on a missing/empty body — unlike
// decodeJSON, which is for required bodies and writes 400 itself on failure.
func decodeOptionalJSON(r *http.Request, dst any) {
	_ = json.NewDecoder(r.Body).Decode(dst)
}

// ─── Self-courses: a student's own private course tree ───────────────────────
// These endpoints give the in-app UI the same capability the connected MCP
// client's create_self_course/add_self_course_module/update_self_course_module
// tools expose — every one is a thin wrapper over the same Service methods,
// so a student's own web session and their connected AI can never diverge in
// what's allowed.

type selfCourseCreateReq struct {
	Title       string   `json:"title"`
	Description *string  `json:"description"`
	Difficulty  string   `json:"difficulty"`
	Tags        []string `json:"tags"`
}

// CreateSelfCourse starts a new private course from scratch, owned by the caller.
func (h *Handler) CreateSelfCourse(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req selfCourseCreateReq
	if !decodeJSON(w, r, &req) {
		return
	}
	if len(req.Title) < 3 || len(req.Title) > 200 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"title": "Title must be 3–200 characters."})
		return
	}
	created, err := h.service.CreateSelfCourse(r.Context(), claims.OrgID, claims.UserID, req.Title, req.Description, req.Difficulty, req.Tags)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, created)
}

// ForkSelfCourse forks a published org course into the caller's own private copy.
func (h *Handler) ForkSelfCourse(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		CourseID string `json:"course_id"`
		Title    string `json:"title"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.CourseID == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"course_id": "course_id is required."})
		return
	}
	if req.Title == "" {
		req.Title = "My Copy"
	}
	fork, err := h.service.ForkSelfCourseFromOrgCourse(r.Context(), claims.OrgID, claims.UserID, req.CourseID, req.Title)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, fork)
}

// GetOrCreateLearningLog handles GET /api/self-courses/learning-log — the
// diary domain's "learned" highlights (see internal/diary) route into this
// same course, so a manual visit and an AI-filed note land in the same
// place. Thin wrapper so the frontend's "Learning Log" entry point (a
// redirect into the existing course-viewer pages) doesn't need to know the
// course id up front.
func (h *Handler) GetOrCreateLearningLog(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	course, err := h.repo.GetOrCreateLearningLogCourse(r.Context(), claims.OrgID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, course)
}

type selfCourseModuleReq struct {
	SectionID   string `json:"section_id"`
	Title       string `json:"title"`
	ContentBody string `json:"content_body"`
}

// AddSelfCourseModule adds a notes module to one of the caller's own self-courses.
func (h *Handler) AddSelfCourseModule(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req selfCourseModuleReq
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.Title == "" || req.ContentBody == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"title": "Title and content_body are required."})
		return
	}
	created, err := h.service.AddSelfCourseModule(r.Context(), claims.OrgID, claims.UserID, urlParam(r, "courseID"), req.SectionID, req.Title, req.ContentBody)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, created)
}

// UpdateSelfCourseModule replaces a module's title/content in one of the caller's own self-courses.
func (h *Handler) UpdateSelfCourseModule(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Title       string `json:"title"`
		ContentBody string `json:"content_body"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.Title == "" || req.ContentBody == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"title": "Title and content_body are required."})
		return
	}
	updated, err := h.service.UpdateSelfCourseModule(r.Context(), claims.OrgID, claims.UserID, urlParam(r, "moduleID"), req.Title, req.ContentBody)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, updated)
}

// DeleteSelfCourseModule soft-deletes one module from one of the caller's
// own self-courses — the in-app counterpart to removing a module the
// connected AI added, without needing the instructor role DELETE
// /api/modules/{moduleID} requires.
func (h *Handler) DeleteSelfCourseModule(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.DeleteSelfCourseModule(r.Context(), claims.OrgID, claims.UserID, urlParam(r, "moduleID")); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// DeleteSelfCourse permanently removes one of the caller's own self-courses
// (and everything under it, via cascade) — the in-app counterpart to the
// create_self_course MCP action's Revert, exposed here so the owner can
// remove a private course from the UI whenever they want, not just via an
// action-log undo.
func (h *Handler) DeleteSelfCourse(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	if err := h.repo.DeleteOwnedSelfCourse(r.Context(), claims.OrgID, claims.UserID, urlParam(r, "courseID")); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// GetLearningContext returns the caller's pre-aggregated learning snapshot —
// enrolled course progress, recent reflections, recent self-course activity.
func (h *Handler) GetLearningContext(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	snapshot, err := h.service.GetLearningContext(r.Context(), claims.OrgID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, snapshot)
}

// ─── Content proposals: self-course → org-course contribution audit ──────────

type proposeModuleReq struct {
	TargetSectionID *string `json:"target_section_id"`
	SourceModuleID  *string `json:"source_module_id"`
	Title           string  `json:"title"`
	ContentBody     string  `json:"content_body"`
}

// ProposeModule queues a pending contribution to a shared org course — never
// applied directly, only an instructor/admin Approve on this course can turn
// it into a real module. Either source_module_id (a module in one of the
// caller's own self-courses, whose content is copied server-side) or both
// title and content_body must be given.
func (h *Handler) ProposeModule(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req proposeModuleReq
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.SourceModuleID == nil && (req.Title == "" || req.ContentBody == "") {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"title": "Provide source_module_id, or both title and content_body."})
		return
	}
	created, err := h.service.ProposeModuleToOrgCourse(r.Context(), claims.OrgID, claims.UserID, urlParam(r, "courseID"), req.TargetSectionID, req.SourceModuleID, req.Title, req.ContentBody)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, created)
}

// ListProposals is the instructor/admin review queue for a course's pending
// (or, with ?status=, any-status) contribution proposals.
func (h *Handler) ListProposals(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	status := queryStr(r, "status")
	if status == "" {
		status = ProposalStatusPending
	}
	proposals, err := h.repo.ListProposalsForCourse(r.Context(), claims.OrgID, urlParam(r, "courseID"), status, queryInt(r, "limit", 100), queryInt(r, "offset", 0))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"proposals": proposals})
}

// ApproveProposal merges a pending proposal into the target org course as a
// real module, inside one transaction (see Repo.ApproveProposal).
func (h *Handler) ApproveProposal(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		ReviewNote *string `json:"review_note"`
	}
	decodeOptionalJSON(r, &req)
	approved, err := h.repo.ApproveProposal(r.Context(), claims.OrgID, urlParam(r, "proposalID"), claims.UserID, req.ReviewNote)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, approved)
}

// RejectProposal marks a pending proposal rejected without creating a module.
func (h *Handler) RejectProposal(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		ReviewNote *string `json:"review_note"`
	}
	decodeOptionalJSON(r, &req)
	rejected, err := h.repo.RejectProposal(r.Context(), claims.OrgID, urlParam(r, "proposalID"), claims.UserID, req.ReviewNote)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, rejected)
}
