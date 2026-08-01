package sheets

import (
	"encoding/json"
	"net/http"
	"time"

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

var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound: {Status: http.StatusNotFound, Message: "Not found."},
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
	claims, ok := auth.RequireClaims(w, r)
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
	claims, ok := auth.RequireClaims(w, r)
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
	claims, ok := auth.RequireClaims(w, r)
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

// GetSheetPreview handles GET /api/sheets/:slug — minimal metadata for the
// share/join flow, visible to any authenticated user.
func (h *Handler) GetSheetPreview(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	slug := chi.URLParam(r, "slug")

	preview, err := h.repo.GetSheetPreview(r.Context(), claims.UserID, slug)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, preview)
}

// UpdateSheet handles PATCH /api/sheets/:id.
func (h *Handler) UpdateSheet(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
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

	var req UpdateSheetRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.Name != nil && *req.Name == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"name": "name cannot be empty.",
		})
		return
	}

	sheet, err := h.repo.UpdateSheet(r.Context(), sheetID, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, sheet)
}

// DeleteSheet handles DELETE /api/sheets/:id.
func (h *Handler) DeleteSheet(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
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

	if err := h.repo.DeleteSheet(r.Context(), sheetID); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// CombineSheets handles POST /api/sheets/combine.
func (h *Handler) CombineSheets(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
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
	if len(req.SheetIDs) < 1 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"sheet_ids": "select at least one sheet.",
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
	claims, ok := auth.RequireClaims(w, r)
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
	claims, ok := auth.RequireClaims(w, r)
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
	claims, ok := auth.RequireClaims(w, r)
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
	claims, ok := auth.RequireClaims(w, r)
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
	claims, ok := auth.RequireClaims(w, r)
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

const maxImportBytes = 10 << 20 // 10MB

// ImportExcel handles POST /api/sheets/import/excel — a multipart .xlsx
// upload. Parses only; nothing is persisted until the client later submits
// the sheet with these rows as custom items.
func (h *Handler) ImportExcel(w http.ResponseWriter, r *http.Request) {
	if _, ok := auth.RequireClaims(w, r); !ok {
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, maxImportBytes+1)
	if err := r.ParseMultipartForm(32 << 20); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Failed to parse multipart form.")
		return
	}
	file, _, err := r.FormFile("file")
	if err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "An .xlsx file is required.")
		return
	}
	defer file.Close()

	items, err := ParseSheetExcel(file)
	if err != nil {
		httputil.WriteError(w, http.StatusUnprocessableEntity, "Could not read the uploaded file: "+err.Error())
		return
	}
	httputil.WriteJSON(w, http.StatusOK, items)
}

// UpdateProgress handles PATCH /api/progress/:topic_tag.
func (h *Handler) UpdateProgress(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
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

	var revisionAt *time.Time
	if req.Status == "done" {
		if req.SheetID == "" {
			httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
				"sheet_id": "sheet_id is required to resolve the revision schedule.",
			})
			return
		}
		settings, err := h.repo.GetSheetSettings(r.Context(), claims.UserID, req.SheetID)
		if err != nil {
			writeDomainError(w, err)
			return
		}
		at := time.Now().AddDate(0, 0, nextRevisionDays(settings.GrowthScheme, settings.BaseRevisionDays, 0))
		revisionAt = &at
	}

	item, err := h.repo.UpsertProgress(r.Context(), claims.UserID, topicTag, req.Status, revisionAt)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, item)
}

// UpdateProgressReview handles PATCH /api/progress/:topic_tag/review — the
// "I still remember this" action, advancing an already-"done" item to its
// next, longer interval per the given sheet's growth scheme.
func (h *Handler) UpdateProgressReview(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	topicTag := chi.URLParam(r, "topic_tag")

	var req MarkReviewedRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.SheetID == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"sheet_id": "sheet_id is required to resolve the revision schedule.",
		})
		return
	}

	item, err := h.repo.MarkReviewed(r.Context(), claims.UserID, topicTag, req.SheetID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, item)
}

// UpdateProgressRevision handles PATCH /api/progress/:topic_tag/revision —
// directly reschedules an already-solved item's revision date, distinct from
// the interval picker shown when first marking it solved.
func (h *Handler) UpdateProgressRevision(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	topicTag := chi.URLParam(r, "topic_tag")

	var req UpdateRevisionRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.RevisionAt.IsZero() {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"revision_at": "revision_at is required.",
		})
		return
	}

	item, err := h.repo.UpdateRevision(r.Context(), claims.UserID, topicTag, req.RevisionAt)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, item)
}

var validGrowthSchemes = map[string]bool{"doubling": true, "ladder": true, "linear": true}

// GetSheetSettings handles GET /api/sheets/settings?sheet_id=...
func (h *Handler) GetSheetSettings(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	sheetID := r.URL.Query().Get("sheet_id")
	if sheetID == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"sheet_id": "sheet_id is required.",
		})
		return
	}

	settings, err := h.repo.GetSheetSettings(r.Context(), claims.UserID, sheetID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, settings)
}

// UpdateSheetSettings handles PUT /api/sheets/settings.
func (h *Handler) UpdateSheetSettings(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req UpdateSheetSettingsRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	fieldErrors := map[string]string{}
	if req.SheetID == "" {
		fieldErrors["sheet_id"] = "sheet_id is required."
	}
	if req.BaseRevisionDays < 1 || req.BaseRevisionDays > 365 {
		fieldErrors["base_revision_days"] = "base_revision_days must be between 1 and 365."
	}
	if !validGrowthSchemes[req.GrowthScheme] {
		fieldErrors["growth_scheme"] = "growth_scheme must be one of: doubling, ladder, linear."
	}
	if len(fieldErrors) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fieldErrors)
		return
	}

	settings, err := h.repo.UpsertSheetSettings(r.Context(), claims.UserID, req.SheetID, req.BaseRevisionDays, req.GrowthScheme)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, settings)
}

// UpdateProgressNotes handles PATCH /api/progress/:topic_tag/notes.
func (h *Handler) UpdateProgressNotes(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	topicTag := chi.URLParam(r, "topic_tag")

	var req UpdateProgressNotesRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if len(req.Notes) == 0 || !json.Valid(req.Notes) {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"notes": "notes must be valid JSON.",
		})
		return
	}

	item, err := h.repo.UpsertNotes(r.Context(), claims.UserID, topicTag, req.Notes)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, item)
}

// UpdateProgressStarred handles PATCH /api/progress/:topic_tag/star.
func (h *Handler) UpdateProgressStarred(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	topicTag := chi.URLParam(r, "topic_tag")

	var req UpdateProgressStarredRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	item, err := h.repo.SetStarred(r.Context(), claims.UserID, topicTag, req.Starred)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, item)
}
