package jobs

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/httputil"
	apimiddleware "github.com/mindforge/backend/internal/middleware"
	"github.com/redis/go-redis/v9"
)

// HTTPHandler wires all job-management HTTP routes.
type HTTPHandler struct {
	pool *pgxpool.Pool
	rdb  *redis.Client
	cfg  *config.Config
	reg  *Registry
}

// NewHTTPHandler creates an HTTPHandler.
func NewHTTPHandler(pool *pgxpool.Pool, rdb *redis.Client, cfg *config.Config, reg *Registry) *HTTPHandler {
	return &HTTPHandler{pool: pool, rdb: rdb, cfg: cfg, reg: reg}
}

// RegisterRoutes mounts all job routes. The parent router must already have
// RequireAuth and RequireCSRF applied.
func (h *HTTPHandler) RegisterRoutes(r chi.Router) {
	// ── Org admin routes ─────────────────────────────────────────────────────
	r.Route("/api/orgs/{orgID}/jobs", func(r chi.Router) {
		r.Use(apimiddleware.RequireOrgMember(h.pool))
		r.Use(apimiddleware.RequireOrgRole(apimiddleware.RoleAdmin, apimiddleware.RoleInstructor))

		r.Get("/", h.handleOrgListJobs)
		r.Get("/{jobID}", h.handleOrgGetJob)
		r.Post("/{jobID}/cancel", h.handleOrgCancelJob)
		r.Post("/{jobID}/retry", h.handleOrgRetryJob)
		r.Patch("/{jobID}", h.handleOrgPatchJob)
	})

	// ── Super admin routes ───────────────────────────────────────────────────
	r.Route("/api/admin/jobs", func(r chi.Router) {
		r.Use(apimiddleware.RequirePlatformRole(h.pool, apimiddleware.PlatformRoleSuperAdmin))

		r.Get("/", h.handleAdminListJobs)
		r.Get("/workers", h.handleAdminListWorkers)
		r.Get("/stats", h.handleAdminStats)
		r.Post("/{jobID}/force-retry", h.handleAdminForceRetry)
	})

	r.Route("/api/admin/orgs/{orgID}", func(r chi.Router) {
		r.Use(apimiddleware.RequirePlatformRole(h.pool, apimiddleware.PlatformRoleSuperAdmin))

		r.Patch("/job-quotas", h.handleAdminUpdateQuota)
		r.Post("/jobs/pause-all", h.handleAdminPauseAll)
	})
}

// ─── Org admin handlers ───────────────────────────────────────────────────────

// GET /api/orgs/{orgID}/jobs
func (h *HTTPHandler) handleOrgListJobs(w http.ResponseWriter, r *http.Request) {
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}

	urlOrgID := chi.URLParam(r, "orgID")
	if urlOrgID != orgCtx.OrgID {
		httputil.WriteError(w, http.StatusForbidden, "Organization mismatch.")
		return
	}

	filter := ListFilter{
		OrgID: &orgCtx.OrgID,
	}

	if s := r.URL.Query().Get("status"); s != "" {
		filter.Status = &s
	}
	if hnd := r.URL.Query().Get("handler"); hnd != "" {
		filter.Handler = &hnd
	}
	filter.After = r.URL.Query().Get("after")

	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	filter.Limit = limit

	jobs, nextCursor, err := List(r.Context(), h.pool, filter)
	if err != nil {
		code, msg := mapError(err)
		httputil.WriteError(w, code, msg)
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"jobs":        jobs,
		"next_cursor": nextCursor,
	})
}

// GET /api/orgs/{orgID}/jobs/{jobID}
func (h *HTTPHandler) handleOrgGetJob(w http.ResponseWriter, r *http.Request) {
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}

	urlOrgID := chi.URLParam(r, "orgID")
	if urlOrgID != orgCtx.OrgID {
		httputil.WriteError(w, http.StatusForbidden, "Organization mismatch.")
		return
	}

	jobID := chi.URLParam(r, "jobID")
	job, err := GetByID(r.Context(), h.pool, jobID, &orgCtx.OrgID)
	if err != nil {
		code, msg := mapError(err)
		httputil.WriteError(w, code, msg)
		return
	}

	runs, err := GetRuns(r.Context(), h.pool, jobID, 20)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "internal server error")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"job":  job,
		"runs": runs,
	})
}

// POST /api/orgs/{orgID}/jobs/{jobID}/cancel
func (h *HTTPHandler) handleOrgCancelJob(w http.ResponseWriter, r *http.Request) {
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}

	urlOrgID := chi.URLParam(r, "orgID")
	if urlOrgID != orgCtx.OrgID {
		httputil.WriteError(w, http.StatusForbidden, "Organization mismatch.")
		return
	}

	jobID := chi.URLParam(r, "jobID")
	err := Cancel(r.Context(), h.pool, jobID, &orgCtx.OrgID)
	if err != nil {
		if errors.Is(err, ErrJobNotFound) {
			httputil.WriteError(w, http.StatusNotFound, "job not found")
			return
		}
		// Cancel returns a non-sentinel error when the job is in the wrong state.
		httputil.WriteError(w, http.StatusConflict, "job cannot be cancelled in its current state")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"job_id": jobID,
	})
}

// POST /api/orgs/{orgID}/jobs/{jobID}/retry
func (h *HTTPHandler) handleOrgRetryJob(w http.ResponseWriter, r *http.Request) {
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}

	urlOrgID := chi.URLParam(r, "orgID")
	if urlOrgID != orgCtx.OrgID {
		httputil.WriteError(w, http.StatusForbidden, "Organization mismatch.")
		return
	}

	jobID := chi.URLParam(r, "jobID")

	// Verify org ownership and that the job is in a retryable state.
	job, err := GetByID(r.Context(), h.pool, jobID, &orgCtx.OrgID)
	if err != nil {
		code, msg := mapError(err)
		httputil.WriteError(w, code, msg)
		return
	}

	if job.Status != StatusFailed && job.Status != StatusDead {
		httputil.WriteError(w, http.StatusConflict, "job cannot be retried in its current state")
		return
	}

	if err := ForceRetry(r.Context(), h.pool, jobID); err != nil {
		if errors.Is(err, ErrJobNotFound) {
			httputil.WriteError(w, http.StatusNotFound, "job not found")
			return
		}
		httputil.WriteError(w, http.StatusConflict, "job cannot be retried in its current state")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"job_id": jobID,
	})
}

// PATCH /api/orgs/{orgID}/jobs/{jobID}
func (h *HTTPHandler) handleOrgPatchJob(w http.ResponseWriter, r *http.Request) {
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return
	}

	urlOrgID := chi.URLParam(r, "orgID")
	if urlOrgID != orgCtx.OrgID {
		httputil.WriteError(w, http.StatusForbidden, "Organization mismatch.")
		return
	}

	jobID := chi.URLParam(r, "jobID")

	var req struct {
		Paused bool `json:"paused"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	job, err := GetByID(r.Context(), h.pool, jobID, &orgCtx.OrgID)
	if err != nil {
		code, msg := mapError(err)
		httputil.WriteError(w, code, msg)
		return
	}

	if job.JobType != "cron" {
		httputil.WriteError(w, http.StatusUnprocessableEntity, "pause/resume is only supported for cron jobs")
		return
	}

	if req.Paused {
		_, err = h.pool.Exec(r.Context(),
			`UPDATE jobs SET deleted_at = NOW(), updated_at = NOW() WHERE id = $1 AND org_id = $2`,
			jobID, orgCtx.OrgID,
		)
	} else {
		_, err = h.pool.Exec(r.Context(),
			`UPDATE jobs SET deleted_at = NULL, updated_at = NOW() WHERE id = $1 AND org_id = $2`,
			jobID, orgCtx.OrgID,
		)
	}
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "internal server error")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"job_id": jobID,
	})
}

// ─── Super admin handlers ─────────────────────────────────────────────────────

// GET /api/admin/jobs
func (h *HTTPHandler) handleAdminListJobs(w http.ResponseWriter, r *http.Request) {
	filter := ListFilter{}

	if orgID := r.URL.Query().Get("org_id"); orgID != "" {
		filter.OrgID = &orgID
	}
	if s := r.URL.Query().Get("status"); s != "" {
		filter.Status = &s
	}
	if hnd := r.URL.Query().Get("handler"); hnd != "" {
		filter.Handler = &hnd
	}
	filter.After = r.URL.Query().Get("after")

	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	filter.Limit = limit

	jobs, nextCursor, err := List(r.Context(), h.pool, filter)
	if err != nil {
		code, msg := mapError(err)
		httputil.WriteError(w, code, msg)
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"jobs":        jobs,
		"next_cursor": nextCursor,
	})
}

// GET /api/admin/jobs/workers
func (h *HTTPHandler) handleAdminListWorkers(w http.ResponseWriter, r *http.Request) {
	workers, err := ListWorkers(r.Context(), h.rdb)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "internal server error")
		return
	}

	leader, err := GetSchedulerLeader(r.Context(), h.rdb)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "internal server error")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"workers": workers,
		"leader":  leader,
	})
}

// GET /api/admin/jobs/stats
func (h *HTTPHandler) handleAdminStats(w http.ResponseWriter, r *http.Request) {
	perOrg, err := PlatformStats(r.Context(), h.pool)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "internal server error")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"per_org": perOrg,
	})
}

// PATCH /api/admin/orgs/{orgID}/job-quotas
func (h *HTTPHandler) handleAdminUpdateQuota(w http.ResponseWriter, r *http.Request) {
	orgID := chi.URLParam(r, "orgID")

	var req struct {
		MaxConcurrent int `json:"max_concurrent"`
		MaxQueued     int `json:"max_queued"`
		PriorityFloor int `json:"priority_floor"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	q := Quota{
		MaxConcurrent: req.MaxConcurrent,
		MaxQueued:     req.MaxQueued,
		PriorityFloor: req.PriorityFloor,
	}
	if err := UpdateQuota(r.Context(), h.pool, orgID, q); err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "internal server error")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"org_id": orgID,
	})
}

// POST /api/admin/orgs/{orgID}/jobs/pause-all
func (h *HTTPHandler) handleAdminPauseAll(w http.ResponseWriter, r *http.Request) {
	orgID := chi.URLParam(r, "orgID")

	tag, err := h.pool.Exec(r.Context(),
		`UPDATE jobs
		 SET status = 'cancelled', updated_at = NOW()
		 WHERE org_id = $1
		   AND status IN ('pending', 'queued')
		   AND deleted_at IS NULL`,
		orgID,
	)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "internal server error")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"cancelled": tag.RowsAffected(),
	})
}

// POST /api/admin/jobs/{jobID}/force-retry
func (h *HTTPHandler) handleAdminForceRetry(w http.ResponseWriter, r *http.Request) {
	jobID := chi.URLParam(r, "jobID")

	if err := ForceRetry(r.Context(), h.pool, jobID); err != nil {
		if errors.Is(err, ErrJobNotFound) {
			httputil.WriteError(w, http.StatusNotFound, "job not found")
			return
		}
		httputil.WriteError(w, http.StatusConflict, "job cannot be retried in its current state")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"job_id": jobID,
	})
}

// ─── error mapping ────────────────────────────────────────────────────────────

func mapError(err error) (int, string) {
	switch {
	case errors.Is(err, ErrJobNotFound):
		return http.StatusNotFound, "job not found"
	case errors.Is(err, ErrQuotaExceeded):
		return http.StatusTooManyRequests, "org job quota exceeded"
	case errors.Is(err, ErrUnknownHandler):
		return http.StatusBadRequest, "unknown job handler"
	case errors.Is(err, ErrDuplicateKey):
		return http.StatusOK, ""
	default:
		return http.StatusInternalServerError, "internal server error"
	}
}
