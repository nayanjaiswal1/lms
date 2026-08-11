package sheets

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/authz"
)

// New builds the fully-wired sheets handler.
func New(pool *pgxpool.Pool) *Handler {
	return NewHandler(pool)
}

// RegisterRoutes mounts the sheets API onto the given router, gated on
// content.sheets — the same permission code the frontend's nav entry and
// <AccessGate> already check, enforced again here since UI gates are UX, not
// security. The caller is responsible for applying RequireAuth + RequireCSRF
// before this.
func (h *Handler) RegisterRoutes(r chi.Router, authzSvc *authz.Service) {
	r.With(authz.RequirePermission(authzSvc, "content.sheets")).Group(func(r chi.Router) {
		r.Get("/api/sheets/public", h.ListPublicSheets)
		r.Post("/api/sheets", h.CreateSheet)
		r.Post("/api/sheets/combine", h.CombineSheets)
		r.Post("/api/sheets/import/excel", h.ImportExcel)
		r.Get("/api/sheets/{slug}", h.GetSheetPreview)
		r.Patch("/api/sheets/{id}", h.UpdateSheet)
		r.Delete("/api/sheets/{id}", h.DeleteSheet)
		r.Get("/api/sheets/{slug}/items", h.GetSheetItems)
		r.Post("/api/sheets/{id}/items", h.AddItem)
		r.Patch("/api/sheets/{id}/items/{itemId}", h.UpdateItem)
		r.Delete("/api/sheets/{id}/items/{itemId}", h.DeleteItem)
		r.Post("/api/sheets/{id}/subscribe", h.Subscribe)
		r.Delete("/api/sheets/{id}/subscribe", h.Unsubscribe)

		r.Get("/api/user/sheets", h.ListUserSheets)
		r.Get("/api/sheets/settings", h.GetSheetSettings)
		r.Put("/api/sheets/settings", h.UpdateSheetSettings)

		r.Patch("/api/progress/{topic_tag}", h.UpdateProgress)
		r.Patch("/api/progress/{topic_tag}/notes", h.UpdateProgressNotes)
		r.Patch("/api/progress/{topic_tag}/revision", h.UpdateProgressRevision)
		r.Patch("/api/progress/{topic_tag}/review", h.UpdateProgressReview)
		r.Patch("/api/progress/{topic_tag}/star", h.UpdateProgressStarred)
	})
}
