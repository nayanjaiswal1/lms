package courses

import (
	"net/http"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// maxAnonMigrateItems bounds how many completed-module/note/reflection
// entries one migration call processes — a real anonymous browsing session
// on one course can't exceed the course's own module count by much, so this
// is generous headroom against a malformed or malicious payload, not a real
// usage limit.
const maxAnonMigrateItems = 500

// MigrateAnonProgress folds the client-side progress an anonymous visitor
// built up on a public course (docs/anonymous.md) into the now-authenticated
// student's real account — the frontend calls this once, right after
// login/register, with whatever it finds in localStorage. Enrollment and
// module completion are done exactly as Enroll/UpdateProgress would do them
// live, so XP/streak/course-completion rewards fire normally; both are
// naturally idempotent (CreateEnrollment's ON CONFLICT DO NOTHING,
// CompleteModule's wasAlreadyCompleted check), so calling this twice for the
// same course is harmless.
func (h *Handler) MigrateAnonProgress(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	courseID := urlParam(r, "courseID")
	course, err := h.repo.GetCourse(r.Context(), claims.OrgID, courseID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	// Anonymous access was only ever offered for is_public courses — a
	// migrate call for anything else means the payload was tampered with or
	// the course changed since the browsing session, either way nothing to
	// import.
	if !course.IsPublic {
		writeDomainError(w, ErrNotFound)
		return
	}

	var req struct {
		CompletedModuleIDs []string          `json:"completed_module_ids"`
		Notes              map[string]string `json:"notes"`
		Reflections        map[string]string `json:"reflections"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	if len(req.CompletedModuleIDs) > maxAnonMigrateItems || len(req.Notes) > maxAnonMigrateItems || len(req.Reflections) > maxAnonMigrateItems {
		writeDomainError(w, ValidationError{Field: "completed_module_ids", Message: "Too many items."})
		return
	}

	if course.IsFree {
		userID := claims.UserID
		if _, err := h.repo.CreateEnrollment(r.Context(), Enrollment{UserID: userID, CourseID: courseID, EnrolledBy: &userID}); err != nil {
			writeDomainError(w, err)
			return
		}
	}

	for _, moduleID := range req.CompletedModuleIDs {
		m, err := h.repo.GetModule(r.Context(), claims.OrgID, moduleID)
		if err != nil || m.CourseID != courseID || !clientCompletableModuleTypes[m.Type] {
			continue // not a real, client-completable module in this course — skip rather than fail the whole batch
		}
		if _, _, err := h.service.CompleteModule(r.Context(), claims.UserID, claims.OrgID, moduleID, courseID); err != nil {
			writeDomainError(w, err)
			return
		}
	}

	for moduleID, content := range req.Notes {
		if content == "" || len(content) > maxLessonNoteLength {
			continue
		}
		m, err := h.repo.GetModule(r.Context(), claims.OrgID, moduleID)
		if err != nil || m.CourseID != courseID {
			continue
		}
		// Best-effort: SaveLessonNote requires enrollment, which only happens
		// above for a free course — a note left on a paid is_public course
		// (an unusual combination) is skipped rather than failing the whole
		// migration over one item.
		if _, err := h.service.SaveLessonNote(r.Context(), claims.OrgID, claims.UserID, moduleID, content, "manual"); err != nil {
			continue
		}
	}

	for moduleID, response := range req.Reflections {
		if response == "" || len(response) > maxReflectionLength {
			continue
		}
		m, err := h.repo.GetModule(r.Context(), claims.OrgID, moduleID)
		if err != nil || m.CourseID != courseID {
			continue
		}
		if _, err := h.repo.UpsertReflection(r.Context(), LessonReflection{
			OrgID:    claims.OrgID,
			UserID:   claims.UserID,
			ModuleID: moduleID,
			Response: response,
		}); err != nil {
			writeDomainError(w, err)
			return
		}
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Progress migrated."})
}
