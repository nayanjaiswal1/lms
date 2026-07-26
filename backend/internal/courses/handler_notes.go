package courses

import (
	"errors"
	"net/http"
	"strings"

	"github.com/mindforge/backend/internal/httputil"
)

// maxLessonNoteLength bounds a student's personal note the same way
// maxReflectionLength bounds the reflection box — long enough for real notes,
// short enough to keep storage bounded.
const maxLessonNoteLength = 20000

// SaveLessonNote handles PUT /api/modules/{moduleID}/notes
// Creates or updates the authenticated student's personal note overlay for a
// module. This is always source="manual" — the AI-written path is the
// save_my_lesson_note MCP tool, which calls Service.SaveLessonNote directly.
func (h *Handler) SaveLessonNote(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Content string `json:"content"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	content := strings.TrimSpace(req.Content)
	if content == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"content": "Write something before saving."})
		return
	}
	if len(content) > maxLessonNoteLength {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"content": "Keep it under 20,000 characters."})
		return
	}
	note, err := h.service.SaveLessonNote(r.Context(), claims.OrgID, claims.UserID, urlParam(r, "moduleID"), content, "manual")
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, note)
}

// GetMyLessonNote handles GET /api/modules/{moduleID}/notes/me
// Returns the authenticated student's existing note for a module, if any —
// used to prefill the notes panel so revisiting a lesson shows what was
// already written instead of a blank box.
func (h *Handler) GetMyLessonNote(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	note, err := h.service.GetMyLessonNote(r.Context(), claims.OrgID, claims.UserID, urlParam(r, "moduleID"))
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httputil.WriteJSON(w, http.StatusOK, map[string]any{"content": nil})
			return
		}
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"content": note.Content, "source": note.Source})
}
