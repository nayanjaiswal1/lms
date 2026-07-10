package sheets

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// Handler exposes the sheets domain over HTTP.
type Handler struct {
	repo *Repo
}

// NewHandler constructs the sheets handler from a connection pool.
func NewHandler(pool *pgxpool.Pool) *Handler {
	return &Handler{repo: NewRepo(pool)}
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
	if errors.Is(err, ErrNotFound) {
		httputil.WriteError(w, http.StatusNotFound, "Not found.")
		return
	}
	httputil.WriteError(w, http.StatusInternalServerError, "Something went wrong.")
}

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
}

// ListPublicSheets handles GET /api/sheets/public.
func (h *Handler) ListPublicSheets(w http.ResponseWriter, r *http.Request) {
	sheets, err := h.repo.ListPublicSheets(r.Context())
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, sheets)
}

// GetSheetItems handles GET /api/sheets/:slug/items.
func (h *Handler) GetSheetItems(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	slug := chi.URLParam(r, "slug")

	sheet, err := h.repo.GetSheetBySlug(r.Context(), slug)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	hasAccess, err := h.repo.UserHasAccess(r.Context(), claims.UserID, sheet.ID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	if !hasAccess {
		httputil.WriteError(w, http.StatusForbidden, "Access denied.")
		return
	}

	items, err := h.repo.ListItemsWithProgress(r.Context(), sheet.ID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, SheetItemsResponse{Sheet: sheet, Items: items})
}

// ListUserSheets handles GET /api/user/sheets.
func (h *Handler) ListUserSheets(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sheets, err := h.repo.ListUserSheets(r.Context(), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, sheets)
}

// CreateSheet handles POST /api/sheets.
func (h *Handler) CreateSheet(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req CreateSheetRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.Name == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"name": "name is required.",
		})
		return
	}

	sheet, err := h.repo.CreateSheet(r.Context(), claims.UserID, slugify(req.Name), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, sheet)
}

// CombineSheets handles POST /api/sheets/combine.
func (h *Handler) CombineSheets(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req CombineSheetsRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.Name == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"name": "name is required.",
		})
		return
	}
	if len(req.SheetIDs) < 2 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"sheet_ids": "select at least 2 sheets to combine.",
		})
		return
	}

	for _, id := range req.SheetIDs {
		hasAccess, err := h.repo.UserHasAccess(r.Context(), claims.UserID, id)
		if err != nil {
			writeDomainError(w, err)
			return
		}
		if !hasAccess {
			httputil.WriteError(w, http.StatusForbidden, "Access denied.")
			return
		}
	}

	sheet, err := h.repo.CombineSheets(r.Context(), claims.UserID, slugify(req.Name), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, sheet)
}

// AddItem handles POST /api/sheets/:id/items.
func (h *Handler) AddItem(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sheetID := chi.URLParam(r, "id")

	isOwner, err := h.repo.IsOwner(r.Context(), claims.UserID, sheetID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	if !isOwner {
		httputil.WriteError(w, http.StatusForbidden, "Access denied.")
		return
	}

	var req AddItemRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.Title == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"title": "title is required.",
		})
		return
	}

	item, err := h.repo.AddItem(r.Context(), sheetID, slugify(req.Title), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, item)
}

// UpdateItem handles PATCH /api/sheets/:id/items/:itemId.
func (h *Handler) UpdateItem(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sheetID := chi.URLParam(r, "id")
	itemID := chi.URLParam(r, "itemId")

	isOwner, err := h.repo.IsOwner(r.Context(), claims.UserID, sheetID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	if !isOwner {
		httputil.WriteError(w, http.StatusForbidden, "Access denied.")
		return
	}

	var req UpdateItemRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	item, err := h.repo.UpdateItem(r.Context(), sheetID, itemID, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, item)
}

// DeleteItem handles DELETE /api/sheets/:id/items/:itemId.
func (h *Handler) DeleteItem(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sheetID := chi.URLParam(r, "id")
	itemID := chi.URLParam(r, "itemId")

	isOwner, err := h.repo.IsOwner(r.Context(), claims.UserID, sheetID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	if !isOwner {
		httputil.WriteError(w, http.StatusForbidden, "Access denied.")
		return
	}

	if err := h.repo.DeleteItem(r.Context(), sheetID, itemID); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// Subscribe handles POST /api/sheets/:id/subscribe.
func (h *Handler) Subscribe(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sheetID := chi.URLParam(r, "id")

	if err := h.repo.Subscribe(r.Context(), claims.UserID, sheetID); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// Unsubscribe handles DELETE /api/sheets/:id/subscribe.
func (h *Handler) Unsubscribe(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sheetID := chi.URLParam(r, "id")

	if err := h.repo.Unsubscribe(r.Context(), claims.UserID, sheetID); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// UpdateProgress handles PATCH /api/progress/:topic_tag.
func (h *Handler) UpdateProgress(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	topicTag := chi.URLParam(r, "topic_tag")

	var req UpdateProgressRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.Status != "todo" && req.Status != "done" && req.Status != "revisit" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"status": "status must be one of: todo, done, revisit.",
		})
		return
	}

	item, err := h.repo.UpsertProgress(r.Context(), claims.UserID, topicTag, req.Status)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, item)
}
