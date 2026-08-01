package roadmap

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// maxRoadmapsPerDay caps how many roadmap generations (create or regenerate)
// a user can trigger per day — same cost class and pattern as
// interviewprep.maxPlansPerDay (each generation is one AI call).
const maxRoadmapsPerDay = 3

type Handler struct {
	service *Service
	repo    *Repo
}

func orgIDPtr(claims *auth.Claims) *string {
	if claims.OrgID == "" {
		return nil
	}
	return &claims.OrgID
}

var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound:          {Status: http.StatusNotFound, Message: "Roadmap not found."},
	ErrAlreadyGenerating: {Status: http.StatusConflict, Message: "This roadmap is already generating."},
	ErrInvalidGoal:       {Status: http.StatusBadRequest, Message: "goal_description is required."},
}

func writeDomainError(w http.ResponseWriter, err error) {
	httputil.WriteDomainError(w, err, domainErrors, "Something went wrong.")
}

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
}

func (h *Handler) CreateRoadmap(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}

	count, err := h.repo.CountRecentRoadmaps(r.Context(), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	if count >= maxRoadmapsPerDay {
		httputil.WriteError(w, http.StatusTooManyRequests, "You've reached today's limit for roadmap generations. Please try again tomorrow.")
		return
	}

	var req CreateRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	rm, err := h.service.Create(r.Context(), claims.UserID, orgIDPtr(claims), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, rm)
}

func (h *Handler) ListRoadmaps(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	roadmaps, err := h.service.List(r.Context(), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"roadmaps": roadmaps})
}

func (h *Handler) ListPublicRoadmaps(w http.ResponseWriter, r *http.Request) {
	if _, ok := auth.RequireClaims(w, r); !ok {
		return
	}
	roadmaps, err := h.service.ListPublic(r.Context())
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"roadmaps": roadmaps})
}

// StartRoadmap forks a public roadmap into a new, independent roadmap owned
// by the caller — an instant copy, no AI call, ready to use immediately.
func (h *Handler) StartRoadmap(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	sourceID := chi.URLParam(r, "roadmapID")
	rm, err := h.service.Fork(r.Context(), sourceID, claims.UserID, orgIDPtr(claims))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, rm)
}

func (h *Handler) GetRoadmap(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "roadmapID")
	rm, err := h.service.Get(r.Context(), id, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, rm)
}

func (h *Handler) RegenerateRoadmap(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}

	count, err := h.repo.CountRecentRoadmaps(r.Context(), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	if count >= maxRoadmapsPerDay {
		httputil.WriteError(w, http.StatusTooManyRequests, "You've reached today's limit for roadmap generations. Please try again tomorrow.")
		return
	}

	id := chi.URLParam(r, "roadmapID")
	if err := h.service.Regenerate(r.Context(), id, claims.UserID, orgIDPtr(claims)); err != nil {
		writeDomainError(w, err)
		return
	}
	rm, err := h.service.Get(r.Context(), id, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, rm)
}

func (h *Handler) UpdateRoadmap(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "roadmapID")

	var body struct {
		Title    *string `json:"title"`
		Status   *string `json:"status"`
		IsPublic *bool   `json:"is_public"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}

	if err := h.service.UpdateRoadmap(r.Context(), id, claims.UserID, body.Title, body.Status, body.IsPublic); err != nil {
		writeDomainError(w, err)
		return
	}
	rm, err := h.service.Get(r.Context(), id, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, rm)
}

func (h *Handler) DeleteRoadmap(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "roadmapID")
	if err := h.service.Delete(r.Context(), id, claims.UserID); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) UpdateModule(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	roadmapID := chi.URLParam(r, "roadmapID")
	moduleID := chi.URLParam(r, "moduleID")

	var body struct {
		Title       *string `json:"title"`
		Description *string `json:"description"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	if body.Title != nil && strings.TrimSpace(*body.Title) == "" {
		httputil.WriteError(w, http.StatusBadRequest, "title cannot be empty.")
		return
	}

	if err := h.service.UpdateModule(r.Context(), roadmapID, moduleID, claims.UserID, body.Title, body.Description); err != nil {
		writeDomainError(w, err)
		return
	}
	rm, err := h.service.Get(r.Context(), roadmapID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, rm)
}

func (h *Handler) DeleteModule(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	roadmapID := chi.URLParam(r, "roadmapID")
	moduleID := chi.URLParam(r, "moduleID")
	if err := h.service.DeleteModule(r.Context(), roadmapID, moduleID, claims.UserID); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) UpdateModuleProgress(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	roadmapID := chi.URLParam(r, "roadmapID")
	moduleID := chi.URLParam(r, "moduleID")

	var body struct {
		Completed bool `json:"completed"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}

	if err := h.service.UpdateModuleProgress(r.Context(), roadmapID, moduleID, claims.UserID, body.Completed); err != nil {
		writeDomainError(w, err)
		return
	}
	rm, err := h.service.Get(r.Context(), roadmapID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, rm)
}
