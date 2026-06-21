package profile

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repo is the data-access layer for the profile domain.
// All methods are scoped to the calling user — no org filtering needed here.
type Repo struct {
	pool *pgxpool.Pool
}

// NewRepo constructs a Repo over the shared connection pool.
func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// tx runs fn inside a transaction, rolling back on error and committing on success.
func (r *Repo) tx(ctx context.Context, fn func(pgx.Tx) error) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("profile: begin tx: %w", err)
	}
	if err := fn(tx); err != nil {
		_ = tx.Rollback(ctx)
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("profile: commit tx: %w", err)
	}
	return nil
}

// isUniqueViolation returns true when err is a PostgreSQL unique-constraint error.
func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}

// ─── GetProfile ───────────────────────────────────────────────────────────────

// GetProfile returns the full profile for userID by LEFT JOINing users and
// user_profiles. When no user_profiles row exists the profile columns are nil /
// zero-value. Skills, social links, and stats are NOT populated here; the
// service loads them in separate calls and sets them on the returned struct.
func (r *Repo) GetProfile(ctx context.Context, userID string) (*Profile, error) {
	const q = `
		SELECT
			u.id, u.name, u.avatar_url, u.email,
			p.display_name, p.bio, p.profile_slug,
			COALESCE(p.public_enabled,    false),
			COALESCE(p.show_skills,       true),
			COALESCE(p.show_achievements, true),
			COALESCE(p.show_certificates, true),
			COALESCE(p.show_activity,     true),
			p.experience_level, p.learning_goal, p.topics_interest,
			p.weekly_time_commitment, p.preferred_learning_style,
			p.current_role, p.years_of_experience,
			p.language, p.timezone, p.weekly_goal_hrs,
			p.notifications,
			COALESCE(p.created_at, u.created_at),
			COALESCE(p.updated_at, u.updated_at)
		FROM users u
		LEFT JOIN user_profiles p ON p.user_id = u.id
		WHERE u.id = $1`

	var (
		prof           Profile
		notifRaw       []byte
		topicsInterest []string
	)

	err := r.pool.QueryRow(ctx, q, userID).Scan(
		&prof.UserID, &prof.Name, &prof.AvatarURL, &prof.Email,
		&prof.DisplayName, &prof.Bio, &prof.ProfileSlug,
		&prof.PublicEnabled, &prof.ShowSkills, &prof.ShowAchievements,
		&prof.ShowCertificates, &prof.ShowActivity,
		&prof.ExperienceLevel, &prof.LearningGoal, &topicsInterest,
		&prof.WeeklyTimeCommitment, &prof.PreferredLearningStyle,
		&prof.CurrentRole, &prof.YearsOfExperience,
		&prof.Language, &prof.Timezone, &prof.WeeklyGoalHrs,
		&notifRaw,
		&prof.CreatedAt, &prof.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("profile: get profile: %w", err)
	}

	prof.TopicsInterest = topicsInterest
	if len(notifRaw) > 0 {
		if err := json.Unmarshal(notifRaw, &prof.Notifications); err != nil {
			return nil, fmt.Errorf("profile: unmarshal notifications: %w", err)
		}
	}

	return &prof, nil
}

// ─── GetSkills ────────────────────────────────────────────────────────────────

// GetSkills returns all skills for userID ordered by skill_name ASC.
func (r *Repo) GetSkills(ctx context.Context, userID string) ([]Skill, error) {
	const q = `
		SELECT id, skill_name, skill_level, created_at
		FROM user_skills
		WHERE user_id = $1
		ORDER BY skill_name ASC`

	rows, err := r.pool.Query(ctx, q, userID)
	if err != nil {
		return nil, fmt.Errorf("profile: get skills: %w", err)
	}
	defer rows.Close()

	var skills []Skill
	for rows.Next() {
		var s Skill
		if err := rows.Scan(&s.ID, &s.SkillName, &s.SkillLevel, &s.CreatedAt); err != nil {
			return nil, fmt.Errorf("profile: scan skill: %w", err)
		}
		skills = append(skills, s)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("profile: iterate skills: %w", err)
	}
	if skills == nil {
		skills = []Skill{}
	}
	return skills, nil
}

// ─── GetSocialLinks ───────────────────────────────────────────────────────────

// GetSocialLinks returns social links for userID. Returns nil (not ErrNotFound)
// when no row exists so the caller can treat it as "links not yet set".
func (r *Repo) GetSocialLinks(ctx context.Context, userID string) (*SocialLinks, error) {
	const q = `
		SELECT linkedin, github, portfolio, updated_at
		FROM user_social_links
		WHERE user_id = $1`

	var sl SocialLinks
	err := r.pool.QueryRow(ctx, q, userID).Scan(
		&sl.LinkedIn, &sl.GitHub, &sl.Portfolio, &sl.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("profile: get social links: %w", err)
	}
	return &sl, nil
}

// ─── GetStats ─────────────────────────────────────────────────────────────────

// GetStats returns aggregated stats for userID. When no user_stats row exists a
// zeroed Stats is returned. The tests_attempted and tests_passed counts are also
// computed from assessment_attempts (the authoritative source) and merged via
// MAX so stored counters are never understated.
func (r *Repo) GetStats(ctx context.Context, userID string) (*Stats, error) {
	var s Stats

	const storedQ = `
		SELECT
			courses_enrolled, courses_completed,
			tests_attempted, tests_passed,
			problems_solved, certificates_earned,
			current_streak_days, learning_hours, roadmaps_completed
		FROM user_stats
		WHERE user_id = $1`

	err := r.pool.QueryRow(ctx, storedQ, userID).Scan(
		&s.CoursesEnrolled, &s.CoursesCompleted,
		&s.TestsAttempted, &s.TestsPassed,
		&s.ProblemsSolved, &s.CertificatesEarned,
		&s.CurrentStreakDays, &s.LearningHours, &s.RoadmapsCompleted,
	)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("profile: get stats: %w", err)
	}

	// Merge with real counts derived from assessment_attempts.
	const attemptsQ = `
		SELECT
			COUNT(*),
			COUNT(*) FILTER (WHERE passed = true)
		FROM assessment_attempts
		WHERE user_id = $1 AND status = 'evaluated'`

	var realAttempted, realPassed int
	if err := r.pool.QueryRow(ctx, attemptsQ, userID).Scan(&realAttempted, &realPassed); err != nil {
		return nil, fmt.Errorf("profile: get attempt stats: %w", err)
	}

	if realAttempted > s.TestsAttempted {
		s.TestsAttempted = realAttempted
	}
	if realPassed > s.TestsPassed {
		s.TestsPassed = realPassed
	}

	return &s, nil
}

// ─── UpsertProfile ────────────────────────────────────────────────────────────

// UpsertProfile upserts user_profiles for userID and optionally updates
// users.name. The tx parameter is non-nil when the call is part of a larger
// transaction (e.g. when social links are also being written). Only non-nil
// pointer fields are applied; existing values are preserved via COALESCE.
// Returns ErrConflict when display_name or profile_slug is taken.
func (r *Repo) UpsertProfile(ctx context.Context, tx pgx.Tx, userID string, input UpdateProfileInput) error {
	var notifRaw []byte
	if input.Notifications != nil {
		var err error
		notifRaw, err = json.Marshal(input.Notifications)
		if err != nil {
			return fmt.Errorf("profile: marshal notifications: %w", err)
		}
	}

	exec := func(q string, args ...interface{}) error {
		var err error
		if tx != nil {
			_, err = tx.Exec(ctx, q, args...)
		} else {
			_, err = r.pool.Exec(ctx, q, args...)
		}
		return err
	}

	if input.Name != nil {
		const nameQ = `UPDATE users SET name = $1, updated_at = now() WHERE id = $2`
		if err := exec(nameQ, *input.Name, userID); err != nil {
			return fmt.Errorf("profile: update user name: %w", err)
		}
	}

	const upsertQ = `
		INSERT INTO user_profiles (
			user_id,
			experience_level, learning_goal, topics_interest,
			weekly_time_commitment, preferred_learning_style,
			current_role, years_of_experience,
			language, timezone, weekly_goal_hrs, notifications,
			display_name, bio,
			public_enabled, show_skills, show_achievements,
			show_certificates, show_activity,
			updated_at
		) VALUES (
			$1,
			$2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14,
			COALESCE($15, false),
			COALESCE($16, true),
			COALESCE($17, true),
			COALESCE($18, true),
			COALESCE($19, true),
			now()
		)
		ON CONFLICT (user_id) DO UPDATE SET
			experience_level         = COALESCE($2,  user_profiles.experience_level),
			learning_goal            = COALESCE($3,  user_profiles.learning_goal),
			topics_interest          = COALESCE($4,  user_profiles.topics_interest),
			weekly_time_commitment   = COALESCE($5,  user_profiles.weekly_time_commitment),
			preferred_learning_style = COALESCE($6,  user_profiles.preferred_learning_style),
			current_role             = COALESCE($7,  user_profiles.current_role),
			years_of_experience      = COALESCE($8,  user_profiles.years_of_experience),
			language                 = COALESCE($9,  user_profiles.language),
			timezone                 = COALESCE($10, user_profiles.timezone),
			weekly_goal_hrs          = COALESCE($11, user_profiles.weekly_goal_hrs),
			notifications            = COALESCE($12, user_profiles.notifications),
			display_name             = COALESCE($13, user_profiles.display_name),
			bio                      = COALESCE($14, user_profiles.bio),
			public_enabled           = COALESCE($15, user_profiles.public_enabled),
			show_skills              = COALESCE($16, user_profiles.show_skills),
			show_achievements        = COALESCE($17, user_profiles.show_achievements),
			show_certificates        = COALESCE($18, user_profiles.show_certificates),
			show_activity            = COALESCE($19, user_profiles.show_activity),
			updated_at               = now()`

	err := exec(upsertQ,
		userID,
		input.ExperienceLevel,
		input.LearningGoal,
		nilOrSlice(input.TopicsInterest),
		input.WeeklyTimeCommitment,
		input.PreferredLearningStyle,
		input.CurrentRole,
		input.YearsOfExperience,
		input.Language,
		input.Timezone,
		input.WeeklyGoalHrs,
		nilOrBytes(notifRaw),
		input.DisplayName,
		input.Bio,
		input.PublicEnabled,
		input.ShowSkills,
		input.ShowAchievements,
		input.ShowCertificates,
		input.ShowActivity,
	)
	if err != nil {
		if isUniqueViolation(err) {
			return ErrConflict
		}
		return fmt.Errorf("profile: upsert profile: %w", err)
	}
	return nil
}

// UpsertProfileSlug sets profile_slug for userID.
// Returns ErrConflict when the slug is taken by another user.
func (r *Repo) UpsertProfileSlug(ctx context.Context, userID, slug string) error {
	const q = `
		INSERT INTO user_profiles (user_id, profile_slug, updated_at)
		VALUES ($1, $2, now())
		ON CONFLICT (user_id) DO UPDATE SET
			profile_slug = EXCLUDED.profile_slug,
			updated_at   = now()`
	_, err := r.pool.Exec(ctx, q, userID, slug)
	if err != nil {
		if isUniqueViolation(err) {
			return ErrConflict
		}
		return fmt.Errorf("profile: upsert slug: %w", err)
	}
	return nil
}

// ─── UpdateAvatar / DeleteAvatar ─────────────────────────────────────────────

// UpdateAvatar sets users.avatar_url for userID.
func (r *Repo) UpdateAvatar(ctx context.Context, userID, avatarURL string) error {
	const q = `UPDATE users SET avatar_url = $1, updated_at = now() WHERE id = $2`
	_, err := r.pool.Exec(ctx, q, avatarURL, userID)
	if err != nil {
		return fmt.Errorf("profile: update avatar: %w", err)
	}
	return nil
}

// DeleteAvatar reads the current avatar_url, sets it to NULL, and returns the
// old URL so the caller can delete the storage object. Returns ("", nil) when
// no avatar was set.
func (r *Repo) DeleteAvatar(ctx context.Context, userID string) (string, error) {
	var oldURL *string
	const selectQ = `SELECT avatar_url FROM users WHERE id = $1`
	if err := r.pool.QueryRow(ctx, selectQ, userID).Scan(&oldURL); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", nil
		}
		return "", fmt.Errorf("profile: read avatar url: %w", err)
	}

	const updateQ = `UPDATE users SET avatar_url = NULL, updated_at = now() WHERE id = $1`
	if _, err := r.pool.Exec(ctx, updateQ, userID); err != nil {
		return "", fmt.Errorf("profile: null avatar url: %w", err)
	}

	if oldURL == nil {
		return "", nil
	}
	return *oldURL, nil
}

// ─── Skills ───────────────────────────────────────────────────────────────────

// AddSkill inserts a new skill for userID.
// Returns ErrConflict when the skill name already exists (case-insensitive).
func (r *Repo) AddSkill(ctx context.Context, userID string, input AddSkillInput) (*Skill, error) {
	const q = `
		INSERT INTO user_skills (user_id, skill_name, skill_level)
		VALUES ($1, $2, $3)
		RETURNING id, skill_name, skill_level, created_at`

	var s Skill
	err := r.pool.QueryRow(ctx, q, userID, input.SkillName, input.SkillLevel).
		Scan(&s.ID, &s.SkillName, &s.SkillLevel, &s.CreatedAt)
	if err != nil {
		if isUniqueViolation(err) {
			return nil, ErrConflict
		}
		return nil, fmt.Errorf("profile: add skill: %w", err)
	}
	return &s, nil
}

// RemoveSkill deletes a skill by id scoped to userID.
// Returns ErrNotFound when the skill does not exist or belongs to another user.
func (r *Repo) RemoveSkill(ctx context.Context, userID, skillID string) error {
	const q = `DELETE FROM user_skills WHERE id = $1 AND user_id = $2`
	tag, err := r.pool.Exec(ctx, q, skillID, userID)
	if err != nil {
		return fmt.Errorf("profile: remove skill: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ─── Social Links ─────────────────────────────────────────────────────────────

// UpsertSocialLinks upserts all three social link columns for userID.
// All three columns are always written (caller passes nil for unset fields).
// The tx parameter is non-nil when operating inside a larger transaction.
func (r *Repo) UpsertSocialLinks(ctx context.Context, tx pgx.Tx, userID string, linkedin, github, portfolio *string) error {
	const q = `
		INSERT INTO user_social_links (user_id, linkedin, github, portfolio, updated_at)
		VALUES ($1, $2, $3, $4, now())
		ON CONFLICT (user_id) DO UPDATE SET
			linkedin   = EXCLUDED.linkedin,
			github     = EXCLUDED.github,
			portfolio  = EXCLUDED.portfolio,
			updated_at = now()`

	var execErr error
	if tx != nil {
		_, execErr = tx.Exec(ctx, q, userID, linkedin, github, portfolio)
	} else {
		_, execErr = r.pool.Exec(ctx, q, userID, linkedin, github, portfolio)
	}
	if execErr != nil {
		return fmt.Errorf("profile: upsert social links: %w", execErr)
	}
	return nil
}

// ─── GetBySlug / SlugExists ───────────────────────────────────────────────────

// GetBySlug returns the full profile for the given profile_slug.
// Returns ErrNotFound when the slug does not exist.
func (r *Repo) GetBySlug(ctx context.Context, slug string) (*Profile, error) {
	const q = `
		SELECT
			u.id, u.name, u.avatar_url, u.email,
			p.display_name, p.bio, p.profile_slug,
			COALESCE(p.public_enabled,    false),
			COALESCE(p.show_skills,       true),
			COALESCE(p.show_achievements, true),
			COALESCE(p.show_certificates, true),
			COALESCE(p.show_activity,     true),
			p.experience_level, p.learning_goal, p.topics_interest,
			p.weekly_time_commitment, p.preferred_learning_style,
			p.current_role, p.years_of_experience,
			p.language, p.timezone, p.weekly_goal_hrs,
			p.notifications,
			COALESCE(p.created_at, u.created_at),
			COALESCE(p.updated_at, u.updated_at)
		FROM user_profiles p
		JOIN users u ON u.id = p.user_id
		WHERE p.profile_slug = $1`

	var (
		prof           Profile
		notifRaw       []byte
		topicsInterest []string
	)

	err := r.pool.QueryRow(ctx, q, slug).Scan(
		&prof.UserID, &prof.Name, &prof.AvatarURL, &prof.Email,
		&prof.DisplayName, &prof.Bio, &prof.ProfileSlug,
		&prof.PublicEnabled, &prof.ShowSkills, &prof.ShowAchievements,
		&prof.ShowCertificates, &prof.ShowActivity,
		&prof.ExperienceLevel, &prof.LearningGoal, &topicsInterest,
		&prof.WeeklyTimeCommitment, &prof.PreferredLearningStyle,
		&prof.CurrentRole, &prof.YearsOfExperience,
		&prof.Language, &prof.Timezone, &prof.WeeklyGoalHrs,
		&notifRaw,
		&prof.CreatedAt, &prof.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("profile: get by slug: %w", err)
	}

	prof.TopicsInterest = topicsInterest
	if len(notifRaw) > 0 {
		if err := json.Unmarshal(notifRaw, &prof.Notifications); err != nil {
			return nil, fmt.Errorf("profile: unmarshal notifications: %w", err)
		}
	}

	return &prof, nil
}

// SlugExists returns true when the given slug is already taken by any user.
func (r *Repo) SlugExists(ctx context.Context, slug string) (bool, error) {
	const q = `SELECT EXISTS(SELECT 1 FROM user_profiles WHERE profile_slug = $1)`
	var exists bool
	if err := r.pool.QueryRow(ctx, q, slug).Scan(&exists); err != nil {
		return false, fmt.Errorf("profile: slug exists: %w", err)
	}
	return exists, nil
}

// ─── helpers ─────────────────────────────────────────────────────────────────

// nilOrSlice dereferences p if non-nil so pgx sees a []string instead of a
// *[]string nil pointer (which it would encode as an empty array, not NULL).
func nilOrSlice(p *[]string) interface{} {
	if p == nil {
		return nil
	}
	return *p
}

// nilOrBytes returns nil when the byte slice is empty so that COALESCE in the
// upsert preserves the existing JSONB value instead of overwriting with NULL.
func nilOrBytes(b []byte) interface{} {
	if len(b) == 0 {
		return nil
	}
	return b
}

// getOldAvatarURL returns the current avatar_url for userID without modifying it.
// Returns ("", nil) when the user has no avatar set.
func (r *Repo) getOldAvatarURL(ctx context.Context, userID string) (string, error) {
	var avatarURL *string
	const q = `SELECT avatar_url FROM users WHERE id = $1`
	if err := r.pool.QueryRow(ctx, q, userID).Scan(&avatarURL); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", nil
		}
		return "", fmt.Errorf("profile: get avatar url: %w", err)
	}
	if avatarURL == nil {
		return "", nil
	}
	return *avatarURL, nil
}

// txUpdateWithLinks runs UpsertProfile and UpsertSocialLinks inside a single
// transaction and, if a slug was generated, sets it afterwards.
func (r *Repo) txUpdateWithLinks(ctx context.Context, userID string, input UpdateProfileInput, slug string) error {
	return r.tx(ctx, func(tx pgx.Tx) error {
		if err := r.UpsertProfile(ctx, tx, userID, input); err != nil {
			return err
		}
		if input.LinkedIn != nil || input.GitHub != nil || input.Portfolio != nil {
			if err := r.UpsertSocialLinks(ctx, tx, userID, input.LinkedIn, input.GitHub, input.Portfolio); err != nil {
				return err
			}
		}
		if slug != "" {
			// Slug upsert happens outside the tx for simplicity (no foreign-key coupling).
			// The profile row already exists after UpsertProfile above, so this
			// update-only path is safe.
			const slugQ = `
				UPDATE user_profiles SET profile_slug = $1, updated_at = now()
				WHERE user_id = $2`
			if _, err := tx.Exec(ctx, slugQ, slug, userID); err != nil {
				if isUniqueViolation(err) {
					return ErrConflict
				}
				return fmt.Errorf("profile: set slug in tx: %w", err)
			}
		}
		return nil
	})
}
