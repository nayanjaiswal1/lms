package profile

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// Handler exposes the profile domain over HTTP.
type Handler struct {
	service *Service
}

// newHandler constructs a Handler from a Service.
func newHandler(svc *Service) *Handler {
	return &Handler{service: svc}
}

// ─── shared helpers ──────────────────────────────────────────────────────────

// ctxClaims pulls the authenticated claims or writes 401 and returns false.
func ctxClaims(w http.ResponseWriter, r *http.Request) (*auth.Claims, bool) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return nil, false
	}
	return claims, true
}

// ─── HandleGetMyProfile ───────────────────────────────────────────────────────

// HandleGetMyProfile handles GET /api/profile/me.
func (h *Handler) HandleGetMyProfile(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}

	prof, err := h.service.GetMyProfile(r.Context(), claims.UserID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httputil.WriteError(w, http.StatusNotFound, "Profile not found.")
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to load profile.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, prof)
}

// ─── HandleUpdateProfile ──────────────────────────────────────────────────────

// HandleUpdateProfile handles PATCH /api/profile/me.
func (h *Handler) HandleUpdateProfile(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}

	var input UpdateProfileInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	prof, err := h.service.UpdateProfile(r.Context(), claims.UserID, input)
	if err != nil {
		if errors.Is(err, ErrConflict) {
			httputil.WriteError(w, http.StatusConflict, "Display name is already taken.")
			return
		}
		httputil.WriteError(w, http.StatusUnprocessableEntity, err.Error())
		return
	}

	httputil.WriteJSON(w, http.StatusOK, prof)
}

// ─── HandleUploadAvatar ───────────────────────────────────────────────────────

// HandleUploadAvatar handles POST /api/profile/me/avatar.
func (h *Handler) HandleUploadAvatar(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, maxAvatarBytes+1)
	if err := r.ParseMultipartForm(32 << 20); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Failed to parse multipart form.")
		return
	}

	file, header, err := r.FormFile("avatar")
	if err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Avatar file is required.")
		return
	}
	defer file.Close()

	avatarURL, err := h.service.UploadAvatar(r.Context(), claims.UserID, file, header.Size)
	if err != nil {
		msg := err.Error()
		switch {
		case containsStr(msg, "under 5 MB"):
			httputil.WriteError(w, http.StatusRequestEntityTooLarge, "Avatar must be under 5 MB.")
		case containsStr(msg, "only JPEG, PNG, and WebP"):
			httputil.WriteError(w, http.StatusUnsupportedMediaType, "Only JPEG, PNG, and WebP avatars are supported.")
		default:
			httputil.WriteError(w, http.StatusInternalServerError, "Failed to upload avatar.")
		}
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]string{"avatar_url": avatarURL})
}

// ─── HandleDeleteAvatar ───────────────────────────────────────────────────────

// HandleDeleteAvatar handles DELETE /api/profile/me/avatar.
func (h *Handler) HandleDeleteAvatar(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}

	if err := h.service.DeleteAvatar(r.Context(), claims.UserID); err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to remove avatar.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Avatar removed."})
}

// ─── HandleGetMySkills ────────────────────────────────────────────────────────

// HandleGetMySkills handles GET /api/profile/me/skills.
func (h *Handler) HandleGetMySkills(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}

	skills, err := h.service.repo.GetSkills(r.Context(), claims.UserID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to load skills.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]interface{}{"skills": skills})
}

// ─── HandleAddSkill ───────────────────────────────────────────────────────────

// HandleAddSkill handles POST /api/profile/me/skills.
func (h *Handler) HandleAddSkill(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}

	var input AddSkillInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	skill, err := h.service.AddSkill(r.Context(), claims.UserID, input)
	if err != nil {
		if errors.Is(err, ErrConflict) {
			httputil.WriteError(w, http.StatusConflict, "Skill already in your profile.")
			return
		}
		httputil.WriteError(w, http.StatusUnprocessableEntity, err.Error())
		return
	}

	httputil.WriteJSON(w, http.StatusCreated, skill)
}

// ─── HandleRemoveSkill ────────────────────────────────────────────────────────

// HandleRemoveSkill handles DELETE /api/profile/me/skills/{skillID}.
func (h *Handler) HandleRemoveSkill(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}

	skillID := chi.URLParam(r, "skillID")
	if skillID == "" {
		httputil.WriteError(w, http.StatusBadRequest, "Skill ID is required.")
		return
	}

	if err := h.service.RemoveSkill(r.Context(), claims.UserID, skillID); err != nil {
		if errors.Is(err, ErrNotFound) {
			httputil.WriteError(w, http.StatusNotFound, "Skill not found.")
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to remove skill.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Skill removed."})
}

// ─── HandleGetUserProfile ─────────────────────────────────────────────────────

// HandleGetUserProfile handles GET /api/profile/user/{userID}.
// Requires authentication. Admins and super_admins can view any user's profile;
// regular users can only view their own.
func (h *Handler) HandleGetUserProfile(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}

	targetUserID := chi.URLParam(r, "userID")
	if targetUserID == "" {
		httputil.WriteError(w, http.StatusBadRequest, "User ID is required.")
		return
	}

	// platform_role is a DB-level concept not stored in the JWT.
	// Pass empty string; only org-role admin and self-access paths apply here.
	prof, err := h.service.GetUserProfile(
		r.Context(),
		claims.UserID,
		"", // platform_role — not available in JWT Claims
		claims.OrgRole,
		targetUserID,
	)
	if err != nil {
		if errors.Is(err, ErrForbidden) {
			httputil.WriteError(w, http.StatusForbidden, "Access denied.")
			return
		}
		if errors.Is(err, ErrNotFound) {
			httputil.WriteError(w, http.StatusNotFound, "User not found.")
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to load profile.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, prof)
}

// ─── HandleGetPublicProfile ───────────────────────────────────────────────────

// HandleGetPublicProfile handles GET /api/profile/public/{slug}.
// No authentication required.
func (h *Handler) HandleGetPublicProfile(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")
	if slug == "" {
		httputil.WriteError(w, http.StatusBadRequest, "Slug is required.")
		return
	}

	prof, err := h.service.GetPublicProfile(r.Context(), slug)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httputil.WriteError(w, http.StatusNotFound, "Profile not found.")
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to load profile.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, prof)
}

// ─── helpers ─────────────────────────────────────────────────────────────────

func containsStr(s, substr string) bool {
	return strings.Contains(s, substr)
}
