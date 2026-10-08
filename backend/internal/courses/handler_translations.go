package courses

import (
	"net/http"
	"regexp"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// maxTranslationBodyLength matches the practical ceiling of an authored
// lesson body; larger payloads are rejected before reaching the database.
const maxTranslationBodyLength = 200000

// localePattern mirrors the CHECK constraint in migration 049 so a bad locale
// is a 422 with a field message, not a database error.
var localePattern = regexp.MustCompile(`^[a-z]{2,3}(-[A-Za-z0-9]{2,8})?$`)

// ListModuleTranslations serves the signed-in learner's and instructor's view
// of a lesson's available languages.
func (h *Handler) ListModuleTranslations(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	translations, err := h.repo.ListModuleTranslations(r.Context(), claims.OrgID, httputil.URLParam(r, "moduleID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"translations": translations})
}

// ListPublicModuleTranslations backs the language switcher on anonymous
// lessons (docs/anonymous.md); no auth, public + published courses only.
func (h *Handler) ListPublicModuleTranslations(w http.ResponseWriter, r *http.Request) {
	translations, err := h.repo.ListPublicModuleTranslations(r.Context(), httputil.URLParam(r, "slug"), httputil.URLParam(r, "moduleID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"translations": translations})
}

// PutModuleTranslation creates or replaces one language version of a lesson.
func (h *Handler) PutModuleTranslation(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	locale := httputil.URLParam(r, "locale")
	if !localePattern.MatchString(locale) {
		writeDomainError(w, ValidationError{Field: "locale", Message: "Locale must look like en, hi or pt-BR."})
		return
	}
	var req struct {
		ContentBody string `json:"content_body"`
	}
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	if req.ContentBody == "" || len(req.ContentBody) > maxTranslationBodyLength {
		writeDomainError(w, ValidationError{Field: "content_body", Message: "Translation is required and must be under 200,000 characters."})
		return
	}
	t, err := h.repo.UpsertModuleTranslation(r.Context(), claims.OrgID, httputil.URLParam(r, "moduleID"), locale, req.ContentBody)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, t)
}

// DeleteModuleTranslation removes one language version of a lesson.
func (h *Handler) DeleteModuleTranslation(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	if err := h.repo.DeleteModuleTranslation(r.Context(), claims.OrgID, httputil.URLParam(r, "moduleID"), httputil.URLParam(r, "locale")); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
