package courses

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/redis/go-redis/v9"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/coupons"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/ratelimit"
)

// PermissionManageRefunds gates POST .../refund — mirrors
// backend/db/migrations/024_receipts_refunds.sql.
const PermissionManageRefunds = "payments.manage_refunds"

const maxUploadSize = 500 << 20 // 500 MB

// CheckoutRequest is what the courses handler asks a CoursePurchaser to
// start. Provider selects which registered payments.Provider handles the
// checkout ("" = the registry's default); CouponCode is optional and
// re-validated/recomputed server-side regardless of what a client displayed.
type CheckoutRequest struct {
	OrgID      string
	UserID     string
	CourseID   string
	Provider   string
	CouponCode string
}

// CheckoutSession is the result of starting a checkout. Exactly one of
// RedirectURL (a hosted checkout page, e.g. Stripe) or ClientParams (fields a
// client-side SDK needs, e.g. Razorpay Checkout.js) is populated — unless
// Status is already "completed" (a zero-total, fully-coupon-covered
// purchase), in which case neither is, since there was nothing to redirect
// the student to.
type CheckoutSession struct {
	PurchaseID    string            `json:"purchase_id"`
	Provider      string            `json:"provider"`
	Status        string            `json:"status"` // "pending" | "completed"
	RedirectURL   string            `json:"redirect_url,omitempty"`
	ClientParams  map[string]string `json:"client_params,omitempty"`
	AmountCents   int               `json:"amount_cents"`
	DiscountCents int               `json:"discount_cents"`
	Currency      string            `json:"currency"`
}

// PurchaseStatus is polled by the frontend's checkout return page — the
// gateway redirect itself never grants access; only a webhook-confirmed
// "completed" status (reflected here) does.
type PurchaseStatus struct {
	PurchaseID string  `json:"purchase_id"`
	Status     string  `json:"status"`
	Enrolled   bool    `json:"enrolled"`
	TicketID   *string `json:"ticket_id,omitempty"`
}

// Receipt is a completed purchase's receipt data. No tax breakdown or GSTIN
// fields — the platform has no GST registration yet, so this is a plain
// payment receipt, not a tax invoice (see docs/infrastructure.md Payments).
// CourseTitle is deliberately absent: the page rendering a receipt already
// has the course loaded from its own fetch, so this doesn't duplicate it.
type Receipt struct {
	PurchaseID    string    `json:"purchase_id"`
	ReceiptNumber *string   `json:"receipt_number"`
	CourseID      string    `json:"course_id"`
	AmountCents   int       `json:"amount_cents"`
	DiscountCents int       `json:"discount_cents"`
	Currency      string    `json:"currency"`
	Provider      string    `json:"provider"`
	Status        string    `json:"status"`
	PurchasedAt   time.Time `json:"purchased_at"`
}

// CoursePurchaser is the narrow capability the courses package needs from
// mentoring.Service to run a paid-course purchase end to end. It is defined
// here (rather than importing the concrete mentoring package) to avoid an
// import cycle: mentoring imports courses for the Enrollment type and
// CreateEnrollmentTx. Unlike the interface this replaced, the DTOs above are
// concrete types owned by this package, so mentoring.Service (which already
// imports courses) can implement this without any `any`-boxing.
type CoursePurchaser interface {
	StartCheckout(ctx context.Context, req CheckoutRequest) (CheckoutSession, error)
	PurchaseStatus(ctx context.Context, orgID, userID, courseID string) (PurchaseStatus, error)
	GetReceipt(ctx context.Context, orgID, userID, purchaseID string) (Receipt, error)
	Refund(ctx context.Context, orgID, purchaseID string) error
}

// conflictError is satisfied by mentoring's ErrAlreadyPurchased (and any
// future sentinel error that represents "this is a conflict, not a server
// fault") without courses needing to import mentoring's concrete error type.
type conflictError interface {
	IsConflict() bool
}

// refundClientError is satisfied by mentoring's clientErr (via errors.As) —
// a refund request the client can fix (e.g. the purchase isn't completed
// yet), not a server fault — without courses needing to import mentoring's
// concrete error type.
type refundClientError interface {
	IsClientError() bool
}

type Handler struct {
	repo      *Repo
	service   *Service
	purchaser CoursePurchaser
	coupons   *coupons.Service
	limiter   *ratelimit.Limiter
	cfg       *config.Config
	authzSvc  *authz.Service
}

// NewHandler wires the courses handler. coupons is imported directly (unlike
// mentoring) since coupons is a leaf package — it depends on neither courses
// nor mentoring, so courses -> coupons introduces no cycle, and PreviewCoupon
// can call it without any interface-boxing indirection. rdb backs the
// per-user coupon-attempt limit (see limitCouponAttempts) — the IP-keyed
// RateLimit middleware cannot carry that, since every browser-facing call
// arrives from the Next.js server on one shared address. authzSvc backs the
// payments.manage_refunds gate on the refund route only (see routes.go).
func NewHandler(repo *Repo, service *Service, purchaser CoursePurchaser, couponsSvc *coupons.Service, rdb *redis.Client, cfg *config.Config, authzSvc *authz.Service) *Handler {
	return &Handler{
		repo: repo, service: service, purchaser: purchaser, coupons: couponsSvc,
		limiter: ratelimit.New(rdb), cfg: cfg, authzSvc: authzSvc,
	}
}

var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound:  {Status: http.StatusNotFound, Message: "Not found."},
	ErrForbidden: {Status: http.StatusForbidden, Message: "Access denied."},
	ErrConflict:  {Status: http.StatusConflict, Message: "Conflict."},
}

func writeDomainError(w http.ResponseWriter, err error) {
	var ve ValidationError
	if errors.As(err, &ve) {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{ve.Field: ve.Message})
		return
	}
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
	Title             string     `json:"title"`
	Description       *string    `json:"description"`
	CoverURL          *string    `json:"cover_url"`
	Difficulty        string     `json:"difficulty"`
	Tags              []string   `json:"tags"`
	EstimatedHours    *float64   `json:"estimated_hours"`
	IsFree            bool       `json:"is_free"`
	Status            string     `json:"status"`
	StartsAt          *time.Time `json:"starts_at"`
	EndsAt            *time.Time `json:"ends_at"`
	DisableCodeRun    bool       `json:"disable_code_run"`
	DisableReflection bool       `json:"disable_reflection"`
}

// validateSchedule checks the shared starts_at/ends_at ordering rule used by
// courses and modules (mirrors assessment.validateBatchSchedule).
func validateSchedule(startsAt, endsAt *time.Time, fields map[string]string) {
	if endsAt != nil && startsAt != nil && !endsAt.After(*startsAt) {
		fields["ends_at"] = "End date must be after the start date."
	}
}

func (h *Handler) CreateCourse(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
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
	if !IsValidDifficulty(diff) {
		fields["difficulty"] = "Invalid difficulty."
	}
	validateSchedule(req.StartsAt, req.EndsAt, fields)
	if len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}
	if req.Tags == nil {
		req.Tags = []string{}
	}

	status := StatusDraft
	if req.Status == StatusPublished {
		status = StatusPublished
	}
	c := Course{
		OrgID:             claims.OrgID,
		CreatorID:         claims.UserID,
		Title:             req.Title,
		Slug:              Slugify(req.Title),
		Description:       req.Description,
		CoverURL:          req.CoverURL,
		Difficulty:        diff,
		Tags:              req.Tags,
		Status:            status,
		IsFree:            req.IsFree,
		EstimatedHours:    req.EstimatedHours,
		StartsAt:          req.StartsAt,
		EndsAt:            req.EndsAt,
		DisableCodeRun:    req.DisableCodeRun,
		DisableReflection: req.DisableReflection,
	}
	created, err := h.repo.CreateCourse(r.Context(), c)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, created)
}

func (h *Handler) GetCourse(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	tree, err := h.repo.GetCourseTree(r.Context(), claims.OrgID, claims.UserID, urlParam(r, "courseID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, tree)
}

// GetCourseBySlug resolves a course by its URL slug for the current viewer,
// folding in enrollment/progress/review — the single call the course detail
// page needs instead of fetching the whole catalog to find one course by
// slug plus several more per-course round trips.
func (h *Handler) GetCourseBySlug(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	detail, err := h.service.GetCourseDetailForViewer(r.Context(), claims.OrgID, claims.UserID, urlParam(r, "slug"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, detail)
}

func (h *Handler) ListCourses(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
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
	// role=instructor means "courses I author" (the instructor-editor pages
	// rely on this to scope drafts to their own owner — see
	// getInstructorCourseBySlug in frontend/lib/server/courses.ts). Any other
	// value, including no role param, is the general browse listing, which
	// ListCourses restricts to published courses regardless of filter.Status.
	if queryStr(r, "role") == "instructor" {
		filter.CreatorID = &claims.UserID
	}
	courses, total, err := h.repo.ListCourses(r.Context(), claims.OrgID, filter)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"courses": courses, "total": total})
}

// ListPublicCourses serves the anonymous landing-page catalog. No auth and no
// org scope — the repo only ever returns published courses with is_public set.
func (h *Handler) ListPublicCourses(w http.ResponseWriter, r *http.Request) {
	courses, total, err := h.repo.ListPublicCourses(r.Context(), queryInt(r, "limit", 12), queryInt(r, "offset", 0))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"courses": courses, "total": total})
}

// GetPublicCourseTree serves a public (is_public, published) course's full
// section/module tree with no auth — backs the anonymous course-learning
// flow (docs/anonymous.md). content_body comes back inline exactly like the
// authenticated tree; the frontend only renders it for notes/system_design
// modules and prompts sign-in for video/pdf/assessment/lab, since those need
// a signed URL or a session tied to a real user that an anonymous visitor
// doesn't have.
func (h *Handler) GetPublicCourseTree(w http.ResponseWriter, r *http.Request) {
	tree, err := h.repo.GetPublicCourseTreeBySlug(r.Context(), urlParam(r, "slug"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, tree)
}

type courseUpdateReq struct {
	Title             string     `json:"title"`
	Description       *string    `json:"description"`
	CoverURL          *string    `json:"cover_url"`
	Difficulty        string     `json:"difficulty"`
	Tags              []string   `json:"tags"`
	EstimatedHours    *float64   `json:"estimated_hours"`
	PriceCents        int        `json:"price_cents"`
	IsFree            bool       `json:"is_free"`
	IsPublic          bool       `json:"is_public"`
	StartsAt          *time.Time `json:"starts_at"`
	EndsAt            *time.Time `json:"ends_at"`
	DisableCodeRun    bool       `json:"disable_code_run"`
	DisableReflection bool       `json:"disable_reflection"`
}

func (h *Handler) UpdateCourse(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req courseUpdateReq
	if !decodeJSON(w, r, &req) {
		return
	}
	fields := map[string]string{}
	validateSchedule(req.StartsAt, req.EndsAt, fields)
	if len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}
	c := Course{
		ID:                urlParam(r, "courseID"),
		Title:             req.Title,
		Description:       req.Description,
		CoverURL:          req.CoverURL,
		Difficulty:        req.Difficulty,
		Tags:              req.Tags,
		EstimatedHours:    req.EstimatedHours,
		PriceCents:        req.PriceCents,
		IsFree:            req.IsFree,
		IsPublic:          req.IsPublic,
		StartsAt:          req.StartsAt,
		EndsAt:            req.EndsAt,
		DisableCodeRun:    req.DisableCodeRun,
		DisableReflection: req.DisableReflection,
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
	claims, ok := auth.RequireClaims(w, r)
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
	claims, ok := auth.RequireClaims(w, r)
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
	claims, ok := auth.RequireClaims(w, r)
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
	claims, ok := auth.RequireClaims(w, r)
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
	claims, ok := auth.RequireClaims(w, r)
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
	claims, ok := auth.RequireClaims(w, r)
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
	claims, ok := auth.RequireClaims(w, r)
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
	CourseID         string     `json:"course_id"`
	Title            string     `json:"title"`
	Type             string     `json:"type"`
	IsFreePreview    bool       `json:"is_free_preview"`
	StorageKey       *string    `json:"storage_key"`
	DurationSeconds  *int       `json:"duration_seconds"`
	ContentBody      *string    `json:"content_body"`
	AssessmentID     *string    `json:"assessment_id"`
	EstimatedMinutes *int       `json:"estimated_minutes"`
	StartsAt         *time.Time `json:"starts_at"`
	EndsAt           *time.Time `json:"ends_at"`
}

func (h *Handler) CreateModule(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
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
	validateSchedule(req.StartsAt, req.EndsAt, fields)
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
		StartsAt:         req.StartsAt,
		EndsAt:           req.EndsAt,
	}
	created, err := h.repo.CreateModule(r.Context(), m)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, created)
}

func (h *Handler) UpdateModule(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
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
	// Lab modules are provisioned outside this endpoint (see ModuleTypeLab)
	// but must remain editable once they exist on a course.
	validTypes := map[string]bool{
		ModuleTypeVideo: true, ModuleTypePDF: true, ModuleTypeNotes: true,
		ModuleTypeAssessment: true, ModuleTypeLab: true,
	}
	if !validTypes[req.Type] {
		fields["type"] = "Type must be video, pdf, notes, assessment, or lab."
	}
	validateSchedule(req.StartsAt, req.EndsAt, fields)
	if len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}
	m := CourseModule{
		ID:               urlParam(r, "moduleID"),
		Title:            req.Title,
		Type:             req.Type,
		IsFreePreview:    req.IsFreePreview,
		StorageKey:       req.StorageKey,
		DurationSeconds:  req.DurationSeconds,
		ContentBody:      req.ContentBody,
		AssessmentID:     req.AssessmentID,
		EstimatedMinutes: req.EstimatedMinutes,
		StartsAt:         req.StartsAt,
		EndsAt:           req.EndsAt,
	}
	updated, err := h.repo.UpdateModule(r.Context(), claims.OrgID, m)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, updated)
}

func (h *Handler) DeleteModule(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
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
	claims, ok := auth.RequireClaims(w, r)
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
	claims, ok := auth.RequireClaims(w, r)
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

// UploadAsset accepts a multipart/form-data upload ("file" field), stores it, and
// returns { url, storage_key }. Used by the course-creation wizard for direct uploads.
func (h *Handler) UploadAsset(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize)
	if err := r.ParseMultipartForm(32 << 20); err != nil {
		httputil.WriteError(w, http.StatusRequestEntityTooLarge, "File too large (max 500 MB).")
		return
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Field 'file' is required.")
		return
	}
	defer file.Close()

	contentType := header.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "application/octet-stream"
	}
	url, key, err := h.service.UploadAsset(r.Context(), claims.OrgID, header.Filename, contentType, header.Size, file)
	if err != nil {
		httputil.WriteError(w, http.StatusServiceUnavailable, "Storage unavailable.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"url": url, "storage_key": key})
}
