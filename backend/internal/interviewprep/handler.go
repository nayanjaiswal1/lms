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

// maxPlansPerDay caps how many prep plans a user can generate per day — each
// creation is 2 AI calls plus a practice-session creation, same cost class as
// the per-day caps already used by labs/practice creation flows.
const maxPlansPerDay = 5

type Handler struct {
	service *Service
	repo    *Repo
}

func ctxClaims(w http.ResponseWriter, r *http.Request) (*auth.Claims, bool) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return nil, false
	}
	return claims, true
}

func writeError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrNotFound):
		httputil.WriteError(w, http.StatusNotFound, "Not found.")
	case errors.Is(err, ErrRoundsIncomplete):
		httputil.WriteError(w, http.StatusConflict, "Both rounds must be completed before viewing the report.")
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
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}

	count, err := h.repo.CountRecentPlans(r.Context(), claims.UserID)
	if err != nil {
		writeError(w, err)
		return
	}
	if count >= maxPlansPerDay {
		httputil.WriteError(w, http.StatusTooManyRequests, "You've reached today's limit for new prep plans. Please try again tomorrow.")
		return
	}

	var body struct {
		JobTitle string `json:"job_title"`
		JDText   string `json:"jd_text"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	if strings.TrimSpace(body.JobTitle) == "" {
		httputil.WriteError(w, http.StatusBadRequest, "job_title is required.")
		return
	}
	if len(body.JDText) > 10000 {
		httputil.WriteError(w, http.StatusBadRequest, "jd_text cannot exceed 10,000 characters.")
		return
	}

	var orgID *string
	if claims.OrgID != "" {
		orgID = &claims.OrgID
	}

	plan, err := h.service.CreatePlan(r.Context(), claims.UserID, orgID, body.JobTitle, body.JDText)
	if err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, plan)
}

func (h *Handler) ListPlans(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
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
	claims, ok := ctxClaims(w, r)
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
	claims, ok := ctxClaims(w, r)
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

	item, err := h.service.SubmitCodingItem(r.Context(), planID, roundID, itemID, claims.UserID, body.Code, body.Language)
	if err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, item)
}

func (h *Handler) GetReport(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	planID := chi.URLParam(r, "planID")
	report, err := h.service.GetReport(r.Context(), planID, claims.UserID)
	if err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, report)
}
