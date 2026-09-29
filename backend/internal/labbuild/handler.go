package labbuild

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/labauthor"
	"github.com/mindforge/backend/internal/labs"
	"github.com/mindforge/backend/internal/library"
)

const maxBodyBytes = 1 << 16

// Handler serves the build/preview/publish endpoints under
// /api/instructor/lab-authoring (docs/debug-labs.md B5).
type Handler struct{ svc *Service }

// NewHandler returns a Handler over svc.
func NewHandler(svc *Service) *Handler { return &Handler{svc: svc} }

// RegisterRoutes mounts the endpoints. Full paths are used (not r.Route) because
// labauthor already owns the /api/instructor/lab-authoring subrouter.
// Building and previewing need labauthor.compose; publishing additionally
// needs courses.publish.
func (h *Handler) RegisterRoutes(r chi.Router, authzSvc *authz.Service) {
	const base = "/api/instructor/lab-authoring"
	compose := authz.RequirePermission(authzSvc, labauthor.PermCompose)
	publish := authz.RequirePermission(authzSvc, labauthor.PermCompose, permCoursesPublish)
	r.With(compose).Post(base+"/recipes/{id}/builds", h.HandleStartBuild)
	r.With(compose).Get(base+"/builds/{id}", h.HandleGetBuild)
	r.With(compose).Post(base+"/builds/{id}/preview-session", h.HandlePreview)
	r.With(publish).Post(base+"/builds/{id}/publish", h.HandlePublish)
}

func writeErr(w http.ResponseWriter, err error) {
	for sentinel := range errSpecs {
		if errors.Is(err, sentinel) {
			if errors.Is(err, ErrBuildRateLimit) {
				w.Header().Set("Retry-After", "3600")
			}
			httputil.WriteDomainError(w, err, errSpecs, "Something went wrong.")
			return
		}
	}
	for _, e := range []error{library.ErrNotFound, library.ErrInvalidKind, library.ErrItemNotEligible, courses.ErrNotFound,
		labs.ErrImageNotAllowed, labs.ErrLabNotPublished, labs.ErrCapacityReached, labs.ErrUserHasActiveSession,
		labs.ErrSessionActive, labs.ErrLabProvisioningUnstable, labs.ErrPlanQuotaExceeded} {
		if errors.Is(err, e) {
			library.WriteError(w, err)
			return
		}
	}
	labauthor.WriteError(w, err)
}

func pathID(w http.ResponseWriter, r *http.Request) (string, bool) {
	id := chi.URLParam(r, "id")
	if _, err := uuid.Parse(id); err != nil {
		httputil.WriteErrorCode(w, http.StatusNotFound, CodeBuildNotFound, "Not found.")
		return "", false
	}
	return id, true
}

func decode(w http.ResponseWriter, r *http.Request, dst any) bool {
	if r.Body == nil || r.ContentLength == 0 {
		return true
	}
	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxBodyBytes))
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		httputil.WriteErrorCode(w, http.StatusBadRequest, labauthor.CodeInvalidInput, "Invalid request body.")
		return false
	}
	return true
}

// HandleStartBuild: POST /recipes/{id}/builds -> 202 {build_id, status}. A
// verified build of the same recipe hash is reused (200, reused=true).
func (h *Handler) HandleStartBuild(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	res, err := h.svc.StartBuild(r.Context(), claims.OrgID, claims.UserID, id)
	if err != nil {
		writeErr(w, err)
		return
	}
	status := http.StatusAccepted
	if res.Reused {
		status = http.StatusOK
	}
	httputil.WriteJSON(w, status, map[string]any{"build_id": res.Build.ID, "status": res.Build.Status, "reused": res.Reused})
}

// HandleGetBuild: GET /builds/{id} -> status, live report and variant keys.
func (h *Handler) HandleGetBuild(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	v, err := h.svc.View(r.Context(), claims.OrgID, id)
	if err != nil {
		writeErr(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, v)
}

// HandlePreview: POST /builds/{id}/preview-session {variant_key?} -> the
// is_test lab session.
func (h *Handler) HandlePreview(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	var body struct {
		VariantKey string `json:"variant_key"`
	}
	if !decode(w, r, &body) {
		return
	}
	session, err := h.svc.Preview(r.Context(), claims.OrgID, claims.UserID, id, body.VariantKey)
	if err != nil {
		writeErr(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, session)
}

// HandlePublish: POST /builds/{id}/publish {course_id, section_id, position,
// is_required} - one transaction; omitted placement falls back to the recipe's
// target_placement.
func (h *Handler) HandlePublish(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	var req PublishReq
	if !decode(w, r, &req) {
		return
	}
	out, err := h.svc.Publish(r.Context(), claims.OrgID, claims.UserID, id, req)
	if err != nil {
		writeErr(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, out)
}
