package interviewprep

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/assessment"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/practice"
)

// New wires the interview-prep package: a self-serve "paste a job title/JD,
// get a scored mock test" flow. It deliberately reuses two existing engines
// rather than reimplementing them — practiceSvc for the conceptual round
// (question generation + AI answer grading) and executor for running/grading
// the generated coding round (same Piston/Judge0 executor the assessment
// package already wires up).
func New(pool *pgxpool.Pool, cfg *config.Config, aiProvider ai.LLMProvider, practiceSvc *practice.Service) *Handler {
	repo := NewRepo(pool)
	executor := assessment.NewExecutor(cfg)
	practiceRepo := practice.NewRepo(pool)
	service := NewService(repo, aiProvider, executor, practiceSvc, practiceRepo, cfg, pool)
	return &Handler{service: service, repo: repo}
}

func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Post("/api/interview-prep", h.CreatePlan)
	r.Get("/api/interview-prep", h.ListPlans)
	r.Get("/api/interview-prep/{planID}", h.GetPlan)
	r.Get("/api/interview-prep/{planID}/report", h.GetReport)
	r.Post("/api/interview-prep/{planID}/rounds/{roundID}/items/{itemID}/submit", h.SubmitCodingItem)
}
