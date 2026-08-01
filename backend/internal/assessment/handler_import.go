package assessment

import (
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/jobs"
)

const maxImportBytes = 10 << 20 // 10MB

// HandleImportParse handles POST /api/batches/{batchID}/import/parse — a
// multipart Excel upload. Parses and validates only; nothing is persisted.
func (h *Handler) HandleImportParse(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")

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

	rows, err := ParseStudentExcel(file)
	if err != nil {
		httputil.WriteError(w, http.StatusUnprocessableEntity, "Could not read the uploaded file: "+err.Error())
		return
	}

	rows, err = h.repo.ValidateAndStatusRows(r.Context(), claims.OrgID, batchID, rows)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"rows": rows})
}

// HandleImportValidate handles POST /api/batches/{batchID}/import/validate —
// re-runs validation/status-detection on admin-edited rows (JSON body).
func (h *Handler) HandleImportValidate(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")

	var body struct {
		Rows []MemberDetailRow `json:"rows"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}

	rows, err := h.repo.ValidateAndStatusRows(r.Context(), claims.OrgID, batchID, body.Rows)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"rows": rows})
}

// batchImportConfirmRequest is the body for POST /import/confirm.
type batchImportConfirmRequest struct {
	Rows         []MemberDetailRow `json:"rows"`
	CourseIDs    []string          `json:"course_ids"`
	MentorIDs    []string          `json:"mentor_ids"`
	LockedFields []string          `json:"locked_fields"`
}

// HandleImportConfirm handles POST /api/batches/{batchID}/import/confirm.
// Assigns the batch-level courses/mentors synchronously, queues the reviewed
// rows as pending import work, and enqueues the background job that creates
// invitations / adds existing members.
func (h *Handler) HandleImportConfirm(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")

	var body batchImportConfirmRequest
	if !decodeJSON(w, r, &body) {
		return
	}
	if len(body.Rows) == 0 {
		httputil.WriteError(w, http.StatusBadRequest, "No rows to import.")
		return
	}

	rows, err := h.repo.ValidateAndStatusRows(r.Context(), claims.OrgID, batchID, body.Rows)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	for _, row := range rows {
		if row.Status == RowStatusInvalid || row.Status == RowStatusDuplicateInFile {
			httputil.WriteError(w, http.StatusBadRequest, "Resolve invalid and duplicate rows before confirming.")
			return
		}
	}

	for _, courseID := range body.CourseIDs {
		if err := h.repo.AssignBatchCourse(r.Context(), claims.OrgID, batchID, courseID, claims.UserID); err != nil {
			writeBatchExtError(w, err)
			return
		}
	}
	for _, mentorID := range body.MentorIDs {
		if err := h.repo.AddBatchMentor(r.Context(), claims.OrgID, batchID, mentorID, claims.UserID); err != nil {
			writeBatchExtError(w, err)
			return
		}
	}

	if err := h.repo.UpsertBatchMemberDetails(r.Context(), batchID, rows, body.LockedFields); err != nil {
		if errors.Is(err, ErrConflict) {
			httputil.WriteError(w, http.StatusConflict, err.Error())
			return
		}
		writeDomainError(w, err)
		return
	}

	payload := map[string]string{"batch_id": batchID, "invited_by": claims.UserID}
	job, err := jobs.Enqueue(r.Context(), h.pool, h.jobRegistry, jobs.EnqueueParams{
		Handler:   "batch_import.students",
		Priority:  jobs.PriorityLow,
		Payload:   payload,
		OrgID:     &claims.OrgID,
		CreatedBy: &claims.UserID,
	})
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to queue import job.")
		return
	}

	httputil.WriteJSON(w, http.StatusAccepted, map[string]string{"job_id": job.ID})
}

// HandleImportReport handles GET /api/batches/{batchID}/import/report.
func (h *Handler) HandleImportReport(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")

	report, err := h.repo.GetImportReport(r.Context(), claims.OrgID, batchID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, report)
}
