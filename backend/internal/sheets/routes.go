package sheets

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// New builds the fully-wired sheets handler.
func New(pool *pgxpool.Pool) *Handler {
	return NewHandler(pool)
}

// RegisterRoutes mounts the sheets API onto the given router.
// The caller is responsible for applying RequireAuth + RequireCSRF before this.
func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Get("/api/sheets/public", h.ListPublicSheets)
	r.Post("/api/sheets", h.CreateSheet)
	r.Post("/api/sheets/combine", h.CombineSheets)
	r.Get("/api/sheets/{slug}/items", h.GetSheetItems)
	r.Post("/api/sheets/{id}/items", h.AddItem)
	r.Patch("/api/sheets/{id}/items/{itemId}", h.UpdateItem)
	r.Delete("/api/sheets/{id}/items/{itemId}", h.DeleteItem)
	r.Post("/api/sheets/{id}/subscribe", h.Subscribe)
	r.Delete("/api/sheets/{id}/subscribe", h.Unsubscribe)

	r.Get("/api/user/sheets", h.ListUserSheets)

	r.Patch("/api/progress/{topic_tag}", h.UpdateProgress)
}
