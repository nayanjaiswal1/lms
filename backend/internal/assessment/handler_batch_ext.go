package assessment

import (
	"errors"
	"net/http"
	"regexp"

	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/httputil"
)

var emailPattern = regexp.MustCompile(`^[^@\s]+@[^@\s]+\.[^@\s]+$`)

func writeBatchExtError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrInvitationExpired):
		httputil.WriteError(w, http.StatusBadRequest, "This invitation has expired.")
	case errors.Is(err, ErrInvitationAlreadyAccepted):
		httputil.WriteError(w, http.StatusConflict, "This invitation has already been accepted.")
	case errors.Is(err, ErrInvitationAlreadyDeclined):
		httputil.WriteError(w, http.StatusConflict, "This invitation has already been declined.")
	case errors.Is(err, ErrEmailMismatch):
		httputil.WriteError(w, http.StatusForbidden, "This invitation was sent to a different email address.")
	case errors.Is(err, ErrUserNotFound):
		httputil.WriteError(w, http.StatusNotFound, "Please register an account before accepting this invitation.")
	default:
		writeDomainError(w, err)
	}
}

func (h *Handler) AddBatchMentor(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")
	var body struct {
		UserID string `json:"user_id"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	if body.UserID == "" {
		httputil.WriteError(w, http.StatusBadRequest, "user_id is required.")
		return
	}
	if err := h.repo.AddBatchMentor(r.Context(), claims.OrgID, batchID, body.UserID, claims.UserID); err != nil {
		writeBatchExtError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (h *Handler) RemoveBatchMentor(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")
	userID := chi.URLParam(r, "userID")
	if err := h.repo.RemoveBatchMentor(r.Context(), claims.OrgID, batchID, userID); err != nil {
		writeBatchExtError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) ListBatchMentors(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")
	mentors, err := h.repo.ListBatchMentors(r.Context(), claims.OrgID, batchID)
	if err != nil {
		writeBatchExtError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"mentors": mentors})
}

func (h *Handler) AssignBatchCourse(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")
	var body struct {
		CourseID string `json:"course_id"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	if body.CourseID == "" {
		httputil.WriteError(w, http.StatusBadRequest, "course_id is required.")
		return
	}
	if err := h.repo.AssignBatchCourse(r.Context(), claims.OrgID, batchID, body.CourseID, claims.UserID); err != nil {
		writeBatchExtError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (h *Handler) UnassignBatchCourse(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")
	courseID := chi.URLParam(r, "courseID")
	if err := h.repo.UnassignBatchCourse(r.Context(), claims.OrgID, batchID, courseID); err != nil {
		writeBatchExtError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) ListBatchCourses(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")
	courses, err := h.repo.ListBatchCourses(r.Context(), claims.OrgID, batchID)
	if err != nil {
		writeBatchExtError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"courses": courses})
}

func (h *Handler) BulkInvite(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")
	var body struct {
		Emails []string `json:"emails"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	if len(body.Emails) == 0 {
		httputil.WriteError(w, http.StatusBadRequest, "At least one email is required.")
		return
	}
	if len(body.Emails) > 500 {
		httputil.WriteError(w, http.StatusBadRequest, "Maximum 500 emails per request.")
		return
	}
	valid := body.Emails[:0]
	for _, e := range body.Emails {
		if emailPattern.MatchString(e) {
			valid = append(valid, e)
		}
	}
	if len(valid) == 0 {
		httputil.WriteError(w, http.StatusBadRequest, "No valid email addresses provided.")
		return
	}
	tokens, err := h.repo.CreateBatchInvitations(r.Context(), claims.OrgID, batchID, claims.UserID, valid)
	if err != nil {
		writeBatchExtError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"invited": len(tokens),
		"tokens":  tokens,
	})
}

func (h *Handler) ListInvitations(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")
	invitations, err := h.repo.ListBatchInvitations(r.Context(), claims.OrgID, batchID)
	if err != nil {
		writeBatchExtError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"invitations": invitations})
}

func (h *Handler) RevokeInvitation(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	invID := chi.URLParam(r, "invID")
	if err := h.repo.RevokeInvitation(r.Context(), claims.OrgID, invID); err != nil {
		writeBatchExtError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) ResendInvitation(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	invID := chi.URLParam(r, "invID")
	token, err := h.repo.ResendInvitation(r.Context(), claims.OrgID, invID)
	if err != nil {
		writeBatchExtError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, token)
}

func (h *Handler) AcceptInvitation(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var body struct {
		Token string `json:"token"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	if body.Token == "" {
		httputil.WriteError(w, http.StatusBadRequest, "token is required.")
		return
	}
	var userEmail string
	if err := h.repo.pool.QueryRow(r.Context(),
		`SELECT email FROM users WHERE id = $1`, claims.UserID,
	).Scan(&userEmail); err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Could not verify your account.")
		return
	}
	batchID, orgID, err := h.repo.AcceptInvitation(r.Context(), body.Token, claims.UserID, userEmail)
	if err != nil {
		writeBatchExtError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"batch_id": batchID, "org_id": orgID})
}

func (h *Handler) DeclineInvitation(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Token string `json:"token"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	if body.Token == "" {
		httputil.WriteError(w, http.StatusBadRequest, "token is required.")
		return
	}
	if err := h.repo.DeclineInvitation(r.Context(), body.Token); err != nil {
		writeBatchExtError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (h *Handler) PreviewInvitation(w http.ResponseWriter, r *http.Request) {
	token := chi.URLParam(r, "token")
	preview, err := h.repo.GetInvitationPreview(r.Context(), token)
	if err != nil {
		writeBatchExtError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, preview)
}

func (h *Handler) GetBatchProgress(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")
	progress, err := h.repo.GetBatchProgress(r.Context(), claims.OrgID, batchID)
	if err != nil {
		writeBatchExtError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"progress": progress})
}
