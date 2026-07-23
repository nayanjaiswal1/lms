package assessment

import (
	"net/http"
	"strings"

	"github.com/mindforge/backend/internal/httputil"
)

// ─── Cohort groups (optional hierarchy above batches, e.g. Class/Section) ─────

type cohortGroupRequest struct {
	Name       string  `json:"name"`
	ParentID   *string `json:"parent_id"`
	LevelLabel *string `json:"level_label"`
}

func (h *Handler) CreateCohortGroup(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req cohortGroupRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if strings.TrimSpace(req.Name) == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"name": "Name is required."})
		return
	}
	g := CohortGroup{
		OrgID:      claims.OrgID,
		ParentID:   req.ParentID,
		Name:       req.Name,
		Slug:       slugify(req.Name),
		LevelLabel: req.LevelLabel,
		CreatedBy:  claims.UserID,
	}
	created, err := h.repo.CreateCohortGroup(r.Context(), g)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, created)
}

func (h *Handler) ListCohortGroups(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	items, err := h.repo.ListCohortGroups(r.Context(), claims.OrgID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"groups": items})
}

func (h *Handler) GetCohortGroup(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	g, err := h.repo.GetCohortGroup(r.Context(), claims.OrgID, chiURLParam(r, "groupID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, g)
}

func (h *Handler) UpdateCohortGroup(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req cohortGroupRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if strings.TrimSpace(req.Name) == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"name": "Name is required."})
		return
	}
	g := CohortGroup{
		ID:         chiURLParam(r, "groupID"),
		ParentID:   req.ParentID,
		Name:       req.Name,
		LevelLabel: req.LevelLabel,
	}
	updated, err := h.repo.UpdateCohortGroup(r.Context(), claims.OrgID, g)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, updated)
}

func (h *Handler) ArchiveCohortGroup(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	if err := h.repo.ArchiveCohortGroup(r.Context(), claims.OrgID, chiURLParam(r, "groupID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Group archived."})
}

type moveBatchToGroupRequest struct {
	CohortGroupID *string `json:"cohort_group_id"`
}

func (h *Handler) MoveBatchToGroup(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req moveBatchToGroupRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if err := h.repo.MoveBatchToGroup(r.Context(), claims.OrgID, chiURLParam(r, "batchID"), req.CohortGroupID); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Batch moved."})
}
