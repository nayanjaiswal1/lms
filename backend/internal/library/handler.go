package library

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/labs"
)

// Handler exposes the library domain over HTTP.
type Handler struct {
	service *Service
}

// NewHandler builds the library HTTP handler.
func NewHandler(service *Service) *Handler { return &Handler{service: service} }

// WriteError maps library/labs/courses placement and lab-start errors to the
// API envelope. Exported so build publish/preview (which place and start labs
// through this package) report them identically.
func WriteError(w http.ResponseWriter, err error) { writeDomainError(w, err) }

func writeDomainError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrNotFound):
		httputil.WriteError(w, http.StatusNotFound, "Not found.")
	case errors.Is(err, ErrInvalidKind):
		httputil.WriteError(w, http.StatusBadRequest, "Invalid kind — must be lab, debug, quiz, or notes.")
	case errors.Is(err, ErrItemNotEligible):
		httputil.WriteError(w, http.StatusUnprocessableEntity, "This item isn't published/eligible to place yet.")
	case errors.Is(err, courses.ErrNotFound):
		httputil.WriteError(w, http.StatusNotFound, "Not found.")
	case errors.Is(err, labs.ErrImageNotAllowed):
		httputil.WriteError(w, http.StatusForbidden, "This lab is not available for your organization.")
	case errors.Is(err, labs.ErrLabNotPublished):
		httputil.WriteError(w, http.StatusConflict, "Lab is not published.")
	case errors.Is(err, labs.ErrCapacityReached):
		httputil.WriteError(w, http.StatusTooManyRequests, "Lab capacity reached, try again shortly.")
	case errors.Is(err, labs.ErrUserHasActiveSession), errors.Is(err, labs.ErrSessionActive):
		httputil.WriteError(w, http.StatusConflict, "You already have a lab running. End it before trying another.")
	case errors.Is(err, labs.ErrLabProvisioningUnstable):
		httputil.WriteError(w, http.StatusServiceUnavailable, "This lab is temporarily unavailable.")
	case errors.Is(err, labs.ErrPlanQuotaExceeded):
		httputil.WriteError(w, http.StatusForbidden, "Lab quota exceeded for your plan.")
	default:
		httputil.WriteError(w, http.StatusInternalServerError, "Something went wrong. Please try again.")
	}
}

// HandleList serves GET /api/library.
func (h *Handler) HandleList(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	q := r.URL.Query()
	var kinds []string
	if raw := q.Get("type"); raw != "" {
		kinds = strings.Split(raw, ",")
	}
	limit, _ := strconv.Atoi(q.Get("limit"))

	page, err := h.service.List(r.Context(), claims.OrgID, ListFilter{
		Kinds:      kinds,
		Search:     strings.TrimSpace(q.Get("q")),
		Cursor:     q.Get("cursor"),
		Limit:      limit,
		Stack:      strings.TrimSpace(q.Get("stack")),
		Category:   strings.TrimSpace(q.Get("category")),
		Difficulty: strings.TrimSpace(q.Get("difficulty")),
	})
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, page)
}

// HandlePreview serves GET /api/library/{kind}/{id}/preview.
func (h *Handler) HandlePreview(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	preview, err := h.service.Preview(r.Context(), claims.OrgID, chi.URLParam(r, "kind"), chi.URLParam(r, "id"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, preview)
}

// HandleTry serves POST /api/library/{kind}/{id}/try — starts an is_test lab
// session, same as an instructor's own "test my lab" button.
func (h *Handler) HandleTry(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	session, err := h.service.Try(r.Context(), claims.OrgID, claims.UserID, chi.URLParam(r, "kind"), chi.URLParam(r, "id"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusAccepted, session)
}

// attachReqBody is the wire shape of POST /api/sections/{sectionID}/library-items.
type attachReqBody struct {
	Kind       string  `json:"kind"`
	ItemID     string  `json:"item_id"`
	Position   *int    `json:"position"`
	Title      *string `json:"title"`
	IsRequired bool    `json:"is_required"`
}

// HandleAttach serves POST /api/sections/{sectionID}/library-items.
func (h *Handler) HandleAttach(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var body attachReqBody
	if !httputil.DecodeJSON(w, r, &body) {
		return
	}
	fields := map[string]string{}
	if body.Kind == "" {
		fields["kind"] = "Kind is required."
	}
	if body.ItemID == "" {
		fields["item_id"] = "item_id is required."
	}
	if body.Position != nil && *body.Position < 0 {
		fields["position"] = "Position must be >= 0."
	}
	if len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}

	inserted, err := h.service.Attach(r.Context(), claims.OrgID, claims.UserID, AttachReq{
		SectionID:  chi.URLParam(r, "sectionID"),
		Position:   body.Position,
		Kind:       body.Kind,
		ItemID:     body.ItemID,
		Title:      body.Title,
		IsRequired: body.IsRequired,
	})
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, inserted)
}
