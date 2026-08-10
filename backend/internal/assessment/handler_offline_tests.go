package assessment

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// CreateOfflineTestScores handles the "Enter Scores" submission — a test
// name, date, max score, and one score per student.
func (h *Handler) CreateOfflineTestScores(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")

	var body struct {
		TestName   string  `json:"test_name"`
		TestDate   string  `json:"test_date"` // YYYY-MM-DD
		MaxScore   float64 `json:"max_score"`
		TemplateID *string `json:"template_id,omitempty"`
		Scores     []struct {
			UserID string  `json:"user_id"`
			Score  float64 `json:"score"`
		} `json:"scores"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	if body.TestName == "" {
		httputil.WriteError(w, http.StatusBadRequest, "test_name is required.")
		return
	}
	if len(body.Scores) == 0 {
		httputil.WriteError(w, http.StatusBadRequest, "At least one score is required.")
		return
	}
	testDate, err := time.Parse("2006-01-02", body.TestDate)
	if err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "test_date must be YYYY-MM-DD.")
		return
	}

	entries := make([]OfflineTestScoreEntry, len(body.Scores))
	for i, s := range body.Scores {
		entries[i] = OfflineTestScoreEntry{UserID: s.UserID, Score: s.Score}
	}

	testID, err := h.repo.CreateOfflineTestScores(
		r.Context(), claims.OrgID, batchID, body.TestName, testDate, body.MaxScore, claims.UserID, entries, body.TemplateID,
	)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, map[string]string{"test_id": testID})
}

// CreateTestTemplate handles saving a reusable offline-test name + default
// max score for the org's "use existing template" dropdown.
func (h *Handler) CreateTestTemplate(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var body struct {
		Name     string  `json:"name"`
		MaxScore float64 `json:"max_score"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	if body.Name == "" {
		httputil.WriteError(w, http.StatusBadRequest, "name is required.")
		return
	}
	if body.MaxScore <= 0 {
		httputil.WriteError(w, http.StatusBadRequest, "max_score must be greater than 0.")
		return
	}
	template, err := h.repo.CreateTestTemplate(r.Context(), claims.OrgID, body.Name, body.MaxScore, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, template)
}

// ListTestTemplates returns every reusable offline-test template for the org.
func (h *Handler) ListTestTemplates(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	templates, err := h.repo.ListTestTemplates(r.Context(), claims.OrgID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"templates": templates})
}

// ListOfflineTests returns every classroom test entered for this batch.
func (h *Handler) ListOfflineTests(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")
	tests, err := h.repo.ListOfflineTests(r.Context(), claims.OrgID, batchID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"tests": tests})
}

// GetOfflineTest returns one test's metadata and every student's score.
func (h *Handler) GetOfflineTest(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")
	testID := chi.URLParam(r, "testID")
	detail, err := h.repo.GetOfflineTestScores(r.Context(), claims.OrgID, batchID, testID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, detail)
}

// UpdateOfflineTestScore edits a single student's score within a test.
func (h *Handler) UpdateOfflineTestScore(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")
	testID := chi.URLParam(r, "testID")
	userID := chi.URLParam(r, "userID")

	var body struct {
		Score float64 `json:"score"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}

	if err := h.repo.UpdateOfflineTestScore(r.Context(), claims.OrgID, batchID, testID, userID, body.Score); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"ok": true})
}
