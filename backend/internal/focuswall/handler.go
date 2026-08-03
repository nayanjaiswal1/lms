package focuswall

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

type Handler struct {
	service *Service
}

func newHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
}

var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound:          {Status: http.StatusNotFound, Message: "Note not found."},
	ErrTextEmpty:         {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"text": "is required"}},
	ErrTextTooLong:       {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"text": "must not exceed 500 characters"}},
	ErrInvalidColor:      {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"color": "must be one of: yellow, blue, pink, green"}},
	ErrInvalidCat:        {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"category": "must be a built-in or a category you've already created"}},
	ErrCategoryNameEmpty: {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"name": "is required"}},
	ErrCategoryTooLong:   {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"name": "must not exceed 24 characters"}},
	ErrCategoryBuiltIn:   {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"name": "is already a built-in category"}},
	ErrCategoryDuplicate: {Status: http.StatusConflict, Message: "You already have a category with this name."},
	ErrCategoryNotFound:  {Status: http.StatusNotFound, Message: "Category not found."},
}

func writeDomainError(w http.ResponseWriter, err error) {
	httputil.WriteDomainError(w, err, domainErrors, "Something went wrong.")
}

// Create handles POST /api/focus-wall/notes
func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req CreateRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	note, err := h.service.Create(r.Context(), claims.UserID, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, note)
}

// Update handles PATCH /api/focus-wall/notes/{noteID}
func (h *Handler) Update(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	noteID := chi.URLParam(r, "noteID")
	var req UpdateRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	note, err := h.service.Update(r.Context(), claims.UserID, noteID, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, note)
}

// Delete handles DELETE /api/focus-wall/notes/{noteID}
func (h *Handler) Delete(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	noteID := chi.URLParam(r, "noteID")
	if err := h.service.Delete(r.Context(), claims.UserID, noteID); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ListMine handles GET /api/focus-wall/notes
func (h *Handler) ListMine(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	notes, err := h.service.ListMine(r.Context(), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, notes)
}

// CreateCategory handles POST /api/focus-wall/categories
func (h *Handler) CreateCategory(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req CreateCategoryRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	category, err := h.service.CreateCategory(r.Context(), claims.UserID, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, category)
}

// ListCategories handles GET /api/focus-wall/categories
func (h *Handler) ListCategories(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	categories, err := h.service.ListCategories(r.Context(), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, categories)
}

// DeleteCategory handles DELETE /api/focus-wall/categories/{categoryID}
func (h *Handler) DeleteCategory(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	categoryID := chi.URLParam(r, "categoryID")
	if err := h.service.DeleteCategory(r.Context(), claims.UserID, categoryID); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
