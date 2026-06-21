package onboarding

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// Handler holds dependencies for onboarding HTTP handlers.
type Handler struct {
	pool *pgxpool.Pool
}

// NewHandler constructs an onboarding Handler.
func NewHandler(pool *pgxpool.Pool) *Handler {
	return &Handler{pool: pool}
}

// ─── request / response types ─────────────────────────────────────────────────

// saveRequest covers both onboarding-wizard fields and personalization prefs.
// All fields are optional; only non-nil fields are written.
type saveRequest struct {
	// Onboarding wizard (v1)
	Timeline        *string `json:"timeline"`
	ExperienceLevel *string `json:"experience_level"`
	RoleIntent      *string `json:"role_intent"`
	Completed       bool    `json:"completed"`

	// Onboarding wizard (v2)
	LearningGoal         *string   `json:"learning_goal"`
	JobTitle             *string   `json:"job_title"`
	TopicsInterest       *[]string `json:"topics_interest"`
	WeeklyTimeCommitment *string   `json:"weekly_time_commitment"`
	SkillLevel           *string   `json:"skill_level"`
	Industry             *string   `json:"industry"`
	CareerGoal           *string   `json:"career_goal"`

	// Personalization
	UITheme       *string          `json:"ui_theme"`
	Language      *string          `json:"language"`
	Timezone      *string          `json:"timezone"`
	WeeklyGoalHrs *int16           `json:"weekly_goal_hrs"`
	Notifications *json.RawMessage `json:"notifications"`
	Meta          *json.RawMessage `json:"meta"`
}

// profileResponse is the full user profile returned by GET /api/user/onboarding.
type profileResponse struct {
	UserID string `json:"user_id"`

	// Onboarding wizard (v1)
	Timeline        *string    `json:"timeline"`
	ExperienceLevel *string    `json:"experience_level"`
	RoleIntent      *string    `json:"role_intent"`
	CompletedAt     *time.Time `json:"completed_at"`

	// Onboarding wizard (v2)
	LearningGoal         *string   `json:"learning_goal"`
	JobTitle             *string   `json:"job_title"`
	TopicsInterest       *[]string `json:"topics_interest"`
	WeeklyTimeCommitment *string   `json:"weekly_time_commitment"`
	SkillLevel           *string   `json:"skill_level"`
	Industry             *string   `json:"industry"`
	CareerGoal           *string   `json:"career_goal"`

	// Personalization
	UITheme       *string          `json:"ui_theme"`
	Language      *string          `json:"language"`
	Timezone      *string          `json:"timezone"`
	WeeklyGoalHrs *int16           `json:"weekly_goal_hrs"`
	Notifications *json.RawMessage `json:"notifications"`
	Meta          *json.RawMessage `json:"meta"`
}

// ─── HandleSave ───────────────────────────────────────────────────────────────

// HandleSave upserts the profile for the authenticated user.
// Any non-nil field overwrites the stored value; omitted fields are preserved.
// Send completed=true to finalize the onboarding wizard.
func (h *Handler) HandleSave(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	var req saveRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	if req.UITheme != nil {
		switch *req.UITheme {
		case "light", "dark", "system":
		default:
			httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
				"ui_theme": "Must be one of: light, dark, system.",
			})
			return
		}
	}

	if req.WeeklyGoalHrs != nil && (*req.WeeklyGoalHrs < 1 || *req.WeeklyGoalHrs > 168) {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"weekly_goal_hrs": "Must be between 1 and 168.",
		})
		return
	}

	var completedAt *time.Time
	if req.Completed {
		now := time.Now()
		completedAt = &now
	}

	if _, err := h.pool.Exec(r.Context(),
		`INSERT INTO user_profiles
		   (user_id, timeline, experience_level, role_intent, completed_at,
		    learning_goal, job_title, topics_interest, weekly_time_commitment, skill_level,
		    industry, career_goal,
		    ui_theme, language, timezone, weekly_goal_hrs, notifications, meta)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)
		 ON CONFLICT (user_id) DO UPDATE SET
		   timeline              = COALESCE($2,  user_profiles.timeline),
		   experience_level      = COALESCE($3,  user_profiles.experience_level),
		   role_intent           = COALESCE($4,  user_profiles.role_intent),
		   completed_at          = COALESCE($5,  user_profiles.completed_at),
		   learning_goal         = COALESCE($6,  user_profiles.learning_goal),
		   job_title             = COALESCE($7,  user_profiles.job_title),
		   topics_interest       = COALESCE($8,  user_profiles.topics_interest),
		   weekly_time_commitment = COALESCE($9, user_profiles.weekly_time_commitment),
		   skill_level           = COALESCE($10, user_profiles.skill_level),
		   industry              = COALESCE($11, user_profiles.industry),
		   career_goal           = COALESCE($12, user_profiles.career_goal),
		   ui_theme              = COALESCE($13, user_profiles.ui_theme),
		   language              = COALESCE($14, user_profiles.language),
		   timezone              = COALESCE($15, user_profiles.timezone),
		   weekly_goal_hrs       = COALESCE($16, user_profiles.weekly_goal_hrs),
		   notifications         = COALESCE($17, user_profiles.notifications),
		   meta                  = COALESCE($18, user_profiles.meta)`,
		claims.UserID,
		req.Timeline,
		req.ExperienceLevel,
		req.RoleIntent,
		completedAt,
		req.LearningGoal,
		req.JobTitle,
		req.TopicsInterest,
		req.WeeklyTimeCommitment,
		req.SkillLevel,
		req.Industry,
		req.CareerGoal,
		req.UITheme,
		req.Language,
		req.Timezone,
		req.WeeklyGoalHrs,
		req.Notifications,
		req.Meta,
	); err != nil {
		slog.Error("onboarding: save upsert", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to save profile.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Saved."})
}

// ─── HandleGet ────────────────────────────────────────────────────────────────

// HandleGet returns the full personalization + onboarding profile.
// Returns a zero-value profile (all nulls) if none has been saved yet.
func (h *Handler) HandleGet(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	p := profileResponse{UserID: claims.UserID}

	err := h.pool.QueryRow(r.Context(),
		`SELECT timeline, experience_level, role_intent, completed_at,
		        learning_goal, job_title, topics_interest, weekly_time_commitment, skill_level,
		        industry, career_goal,
		        ui_theme, language, timezone, weekly_goal_hrs, notifications, meta
		 FROM user_profiles
		 WHERE user_id = $1`,
		claims.UserID,
	).Scan(
		&p.Timeline, &p.ExperienceLevel, &p.RoleIntent, &p.CompletedAt,
		&p.LearningGoal, &p.JobTitle, &p.TopicsInterest, &p.WeeklyTimeCommitment, &p.SkillLevel,
		&p.Industry, &p.CareerGoal,
		&p.UITheme, &p.Language, &p.Timezone, &p.WeeklyGoalHrs,
		&p.Notifications, &p.Meta,
	)
	if err != nil {
		// No profile row yet — return the zero-value profile (all nulls)
		httputil.WriteJSON(w, http.StatusOK, map[string]any{"profile": p})
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{"profile": p})
}
