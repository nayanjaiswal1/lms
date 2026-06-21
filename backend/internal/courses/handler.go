package courses

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
	repo    *Repo
	service *Service
}

func NewHandler(repo *Repo, service *Service) *Handler {
	return &Handler{repo: repo, service: service}
}

func ctxClaims(w http.ResponseWriter, r *http.Request) (*auth.Claims, bool) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return nil, false
	}
	return claims, true
}

func writeDomainError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrNotFound):
		httputil.WriteError(w, http.StatusNotFound, "Not found.")
	case errors.Is(err, ErrForbidden):
		httputil.WriteError(w, http.StatusForbidden, "Access denied.")
	case errors.Is(err, ErrConflict):
		httputil.WriteError(w, http.StatusConflict, "Conflict.")
	default:
		httputil.WriteError(w, http.StatusInternalServerError, "Something went wrong.")
	}
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

func queryStr(r *http.Request, key string) string {
	return r.URL.Query().Get(key)
}

func queryInt(r *http.Request, key string, def int) int {
	if v := r.URL.Query().Get(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}

// ─── Course CRUD ──────────────────────────────────────────────────────────────

type courseCreateReq struct {
	Title          string   `json:"title"`
	Description    *string  `json:"description"`
	Difficulty     string   `json:"difficulty"`
	Tags           []string `json:"tags"`
	EstimatedHours *float64 `json:"estimated_hours"`
}

func (h *Handler) CreateCourse(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req courseCreateReq
	if !decodeJSON(w, r, &req) {
		return
	}
	fields := map[string]string{}
	if len(req.Title) < 3 || len(req.Title) > 200 {
		fields["title"] = "Title must be 3–200 characters."
	}
	diff := req.Difficulty
	if diff == "" {
		diff = DifficultyBeginner
	}
	if diff != DifficultyBeginner && diff != DifficultyIntermediate && diff != DifficultyAdvanced {
		fields["difficulty"] = "Invalid difficulty."
	}
	if len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}
	if req.Tags == nil {
		req.Tags = []string{}
	}

	c := Course{
		OrgID:          claims.OrgID,
		CreatorID:      claims.UserID,
		Title:          req.Title,
		Slug:           Slugify(req.Title),
		Description:    req.Description,
		Difficulty:     diff,
		Tags:           req.Tags,
		Status:         StatusDraft,
		IsFree:         true,
		EstimatedHours: req.EstimatedHours,
	}
	created, err := h.repo.CreateCourse(r.Context(), c)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, created)
}

func (h *Handler) GetCourse(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	tree, err := h.repo.GetCourseTree(r.Context(), claims.OrgID, urlParam(r, "courseID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, tree)
}

func (h *Handler) ListCourses(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	filter := CourseFilter{
		Status:     queryStr(r, "status"),
		Difficulty: queryStr(r, "difficulty"),
		Search:     queryStr(r, "q"),
		Limit:      queryInt(r, "limit", 20),
		Offset:     queryInt(r, "offset", 0),
	}
	courses, total, err := h.repo.ListCourses(r.Context(), claims.OrgID, filter)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"courses": courses, "total": total})
}

type courseUpdateReq struct {
	Title          string   `json:"title"`
	Description    *string  `json:"description"`
	CoverURL       *string  `json:"cover_url"`
	Difficulty     string   `json:"difficulty"`
	Tags           []string `json:"tags"`
	EstimatedHours *float64 `json:"estimated_hours"`
	PriceCents     int      `json:"price_cents"`
	IsFree         bool     `json:"is_free"`
}

func (h *Handler) UpdateCourse(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req courseUpdateReq
	if !decodeJSON(w, r, &req) {
		return
	}
	c := Course{
		ID:             urlParam(r, "courseID"),
		Title:          req.Title,
		Description:    req.Description,
		CoverURL:       req.CoverURL,
		Difficulty:     req.Difficulty,
		Tags:           req.Tags,
		EstimatedHours: req.EstimatedHours,
		PriceCents:     req.PriceCents,
		IsFree:         req.IsFree,
	}
	if c.Tags == nil {
		c.Tags = []string{}
	}
	updated, err := h.repo.UpdateCourse(r.Context(), claims.OrgID, c)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, updated)
}

func (h *Handler) PublishCourse(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	if err := h.repo.PublishCourse(r.Context(), claims.OrgID, urlParam(r, "courseID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"status": "published"})
}

func (h *Handler) DeleteCourse(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	if err := h.repo.ArchiveCourse(r.Context(), claims.OrgID, urlParam(r, "courseID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"status": "archived"})
}

func (h *Handler) ForkCourse(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Title string `json:"title"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.Title == "" {
		req.Title = "Forked Course"
	}
	fork, err := h.repo.ForkCourse(r.Context(), claims.OrgID, urlParam(r, "courseID"), claims.UserID, req.Title, Slugify(req.Title))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, fork)
}

// ─── Sections ─────────────────────────────────────────────────────────────────

func (h *Handler) CreateSection(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Title string `json:"title"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.Title == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"title": "Title is required."})
		return
	}
	courseID := urlParam(r, "courseID")
	if _, err := h.repo.GetCourse(r.Context(), claims.OrgID, courseID); err != nil {
		writeDomainError(w, err)
		return
	}
	s := CourseSection{CourseID: courseID, Title: req.Title}
	created, err := h.repo.CreateSection(r.Context(), s)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, created)
}

func (h *Handler) UpdateSection(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Title string `json:"title"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	s := CourseSection{ID: urlParam(r, "sectionID"), Title: req.Title}
	updated, err := h.repo.UpdateSection(r.Context(), claims.OrgID, s)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, updated)
}

func (h *Handler) DeleteSection(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	if err := h.repo.DeleteSection(r.Context(), claims.OrgID, urlParam(r, "sectionID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Section deleted."})
}

func (h *Handler) ReorderSections(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		SectionIDs []string `json:"section_ids"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	if err := h.repo.ReorderSections(r.Context(), claims.OrgID, urlParam(r, "courseID"), req.SectionIDs); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Sections reordered."})
}

// ─── Modules ──────────────────────────────────────────────────────────────────

type moduleCreateReq struct {
	CourseID         string  `json:"course_id"`
	Title            string  `json:"title"`
	Type             string  `json:"type"`
	IsFreePreview    bool    `json:"is_free_preview"`
	StorageKey       *string `json:"storage_key"`
	DurationSeconds  *int    `json:"duration_seconds"`
	ContentBody      *string `json:"content_body"`
	AssessmentID     *string `json:"assessment_id"`
	EstimatedMinutes *int    `json:"estimated_minutes"`
}

func (h *Handler) CreateModule(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req moduleCreateReq
	if !decodeJSON(w, r, &req) {
		return
	}
	fields := map[string]string{}
	if req.Title == "" {
		fields["title"] = "Title is required."
	}
	validTypes := map[string]bool{ModuleTypeVideo: true, ModuleTypePDF: true, ModuleTypeNotes: true, ModuleTypeAssessment: true}
	if !validTypes[req.Type] {
		fields["type"] = "Type must be video, pdf, notes, or assessment."
	}
	if len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}
	sectionID := urlParam(r, "sectionID")
	section, err := h.repo.GetSectionForOrg(r.Context(), claims.OrgID, sectionID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	m := CourseModule{
		CourseID:         section.CourseID,
		SectionID:        sectionID,
		Title:            req.Title,
		Type:             req.Type,
		IsFreePreview:    req.IsFreePreview,
		StorageKey:       req.StorageKey,
		DurationSeconds:  req.DurationSeconds,
		ContentBody:      req.ContentBody,
		AssessmentID:     req.AssessmentID,
		EstimatedMinutes: req.EstimatedMinutes,
	}
	created, err := h.repo.CreateModule(r.Context(), m)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, created)
}

func (h *Handler) UpdateModule(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req moduleCreateReq
	if !decodeJSON(w, r, &req) {
		return
	}
	m := CourseModule{
		ID:               urlParam(r, "moduleID"),
		Title:            req.Title,
		IsFreePreview:    req.IsFreePreview,
		StorageKey:       req.StorageKey,
		DurationSeconds:  req.DurationSeconds,
		ContentBody:      req.ContentBody,
		AssessmentID:     req.AssessmentID,
		EstimatedMinutes: req.EstimatedMinutes,
	}
	updated, err := h.repo.UpdateModule(r.Context(), claims.OrgID, m)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, updated)
}

func (h *Handler) DeleteModule(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	if err := h.repo.SoftDeleteModule(r.Context(), claims.OrgID, urlParam(r, "moduleID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Module deleted."})
}

func (h *Handler) ReorderModules(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		ModuleIDs []string `json:"module_ids"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	if err := h.repo.ReorderModules(r.Context(), claims.OrgID, urlParam(r, "sectionID"), req.ModuleIDs); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Modules reordered."})
}

// ─── Upload ───────────────────────────────────────────────────────────────────

func (h *Handler) GetUploadURL(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		CourseID string `json:"course_id"`
		ModuleID string `json:"module_id"`
		MimeType string `json:"mime_type"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.MimeType == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"mime_type": "MIME type required."})
		return
	}
	uploadURL, key, err := h.service.PresignedUploadURL(r.Context(), claims.OrgID, req.CourseID, req.ModuleID, req.MimeType)
	if err != nil {
		httputil.WriteError(w, http.StatusServiceUnavailable, "Storage unavailable.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"upload_url": uploadURL, "storage_key": key})
}
