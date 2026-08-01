package interviewprep

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

type Handler struct {
	// Service is exported so it can be shared with the mcpconnect package's
	// interview-prep tools — the same instance a student's connected AI calls
	// enforces the identical validation and daily rate limit as this handler,
	// rather than either side re-implementing those rules.
	Service *Service
	repo    *Repo
}

func writeError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrNotFound):
		httputil.WriteError(w, http.StatusNotFound, "Not found.")
	case errors.Is(err, ErrRoundsIncomplete):
		httputil.WriteError(w, http.StatusConflict, "Both rounds must be completed before viewing the report.")
	case errors.Is(err, ErrNoReportForQuickPlan):
		httputil.WriteError(w, http.StatusBadRequest, "Quick sessions don't generate a readiness report.")
	case errors.Is(err, ErrDailyLimitReached):
		httputil.WriteError(w, http.StatusTooManyRequests, "You've reached today's limit for new prep plans. Please try again tomorrow.")
	case errors.Is(err, ErrInvalidMode):
		httputil.WriteError(w, http.StatusBadRequest, "mode must be 'quick' or 'targeted'.")
	case errors.Is(err, ErrJobTitleRequired):
		httputil.WriteError(w, http.StatusBadRequest, "job_title is required.")
	case errors.Is(err, ErrJDTextTooLong):
		httputil.WriteError(w, http.StatusBadRequest, "jd_text cannot exceed 10,000 characters.")
	case errors.Is(err, ErrTechnologyRequired):
		httputil.WriteError(w, http.StatusBadRequest, "technology is required.")
	case errors.Is(err, context.DeadlineExceeded), errors.Is(err, context.Canceled):
		httputil.WriteError(w, http.StatusServiceUnavailable, "AI response timed out. Please try again.")
	default:
		msg := err.Error()
		if strings.Contains(msg, "AI provider not available") || strings.Contains(msg, "code execution unavailable") {
			httputil.WriteError(w, http.StatusServiceUnavailable, "This feature is temporarily unavailable. Please try again later.")
			return
		}
		slog.Error("interviewprep: unhandled error", "error", err)
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

func (h *Handler) CreatePlan(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}

	var body struct {
		Mode          string `json:"mode"`
		JobTitle      string `json:"job_title"`
		JDText        string `json:"jd_text"`
		Technology    string `json:"technology"`
		Difficulty    string `json:"difficulty"`
		Category      string `json:"category"`
		QuestionCount int    `json:"question_count"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}

	var orgID *string
	if claims.OrgID != "" {
		orgID = &claims.OrgID
	}

	plan, err := h.Service.CreatePlan(r.Context(), claims.UserID, orgID, CreatePlanInput{
		Mode:          body.Mode,
		JobTitle:      body.JobTitle,
		JDText:        body.JDText,
		Technology:    body.Technology,
		Difficulty:    body.Difficulty,
		Category:      body.Category,
		QuestionCount: body.QuestionCount,
	})
	if err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, plan)
}

func (h *Handler) ListPlans(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	plans, err := h.repo.ListPlans(r.Context(), claims.UserID)
	if err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"plans": plans})
}

func (h *Handler) GetPlan(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	planID := chi.URLParam(r, "planID")
	plan, err := h.repo.GetPlan(r.Context(), planID, claims.UserID)
	if err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, plan)
}

func (h *Handler) SubmitCodingItem(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	planID := chi.URLParam(r, "planID")
	roundID := chi.URLParam(r, "roundID")
	itemID := chi.URLParam(r, "itemID")

	var body struct {
		Code     string `json:"code"`
		Language string `json:"language"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	if strings.TrimSpace(body.Code) == "" || strings.TrimSpace(body.Language) == "" {
		httputil.WriteError(w, http.StatusBadRequest, "code and language are required.")
		return
	}

	item, err := h.Service.SubmitCodingItem(r.Context(), planID, roundID, itemID, claims.UserID, body.Code, body.Language)
	if err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, item)
}

func (h *Handler) GetReport(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	planID := chi.URLParam(r, "planID")
	report, err := h.Service.GetReport(r.Context(), planID, claims.UserID)
	if err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, report)
}
