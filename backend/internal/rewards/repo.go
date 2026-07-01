package rewards

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

// ─── Redis key schema ─────────────────────────────────────────────────────────
//
//	leaderboard:global                          — platform-wide
//	leaderboard:org:{org_id}                    — org-scoped
//	leaderboard:batch:{batch_id}                — batch/bootcamp-scoped
//	leaderboard:course:{course_id}              — course-scoped
//	leaderboard:feature:org:{org_id}:problems   — problems only
//	leaderboard:feature:org:{org_id}:quizzes    — quizzes only
//	user_lb_profile:{user_id}                   — display data hash (TTL 10 min)

const userProfileTTL = 10 * time.Minute

// Repo handles all DB and Redis operations for the rewards domain.
type Repo struct {
	pool *pgxpool.Pool
	rdb  *redis.Client
}

func NewRepo(pool *pgxpool.Pool, rdb *redis.Client) *Repo {
	return &Repo{pool: pool, rdb: rdb}
}

// ─── PostgreSQL: XP ──────────────────────────────────────────────────────────

// AddXPAndGetTotal inserts an xp_event and atomically increments user_stats.total_xp.
// Returns (newTotalXP, currentLevelInDB, error). The level in DB is the value
// BEFORE this call updates it — used to detect a level-up.
func (r *Repo) AddXPAndGetTotal(ctx context.Context, req AwardXPRequest) (newTotal int, currentLevel int, err error) {
	tx, txErr := r.pool.Begin(ctx)
	if txErr != nil {
		return 0, 0, fmt.Errorf("rewards: begin tx: %w", txErr)
	}
	defer tx.Rollback(ctx)

	var batchID, courseID, refID, refType *string
	if req.BatchID != nil && *req.BatchID != "" {
		batchID = req.BatchID
	}
	if req.CourseID != nil && *req.CourseID != "" {
		courseID = req.CourseID
	}
	if req.RefID != nil && *req.RefID != "" {
		refID = req.RefID
	}
	if req.RefType != nil && *req.RefType != "" {
		refType = req.RefType
	}
	var orgID *string
	if req.OrgID != "" {
		orgID = &req.OrgID
	}

	if _, execErr := tx.Exec(ctx, `
		INSERT INTO xp_events
		  (user_id, org_id, batch_id, course_id, xp_amount, reason, reference_id, reference_type)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		req.UserID, orgID, batchID, courseID, req.XP, req.Reason, refID, refType,
	); execErr != nil {
		return 0, 0, fmt.Errorf("rewards: insert xp_event: %w", execErr)
	}

	// UPSERT user_stats — returns new total_xp and the CURRENT (pre-level-update) xp_level.
	if scanErr := tx.QueryRow(ctx, `
		INSERT INTO user_stats (user_id, total_xp, xp_level, xp_level_name)
		VALUES ($1, $2, 1, 'Apprentice')
		ON CONFLICT (user_id) DO UPDATE
		  SET total_xp   = user_stats.total_xp + EXCLUDED.total_xp,
		      updated_at = now()
		RETURNING total_xp, xp_level`,
		req.UserID, req.XP,
	).Scan(&newTotal, &currentLevel); scanErr != nil {
		return 0, 0, fmt.Errorf("rewards: upsert user_stats: %w", scanErr)
	}

	if commitErr := tx.Commit(ctx); commitErr != nil {
		return 0, 0, fmt.Errorf("rewards: commit: %w", commitErr)
	}
	return newTotal, currentLevel, nil
}

// UpdateUserLevel writes the computed level name and number to user_stats.
func (r *Repo) UpdateUserLevel(ctx context.Context, userID string, level UserLevel) error {
	_, err := r.pool.Exec(ctx, `
		UPDATE user_stats SET xp_level = $2, xp_level_name = $3, updated_at = now()
		WHERE user_id = $1`,
		userID, level.Level, level.Name)
	if err != nil {
		return fmt.Errorf("rewards: update user level: %w", err)
	}
	return nil
}

// UpdateDailyStreak increments current_streak_days on the first XP event of each
// calendar day. Subsequent events on the same day are no-ops. A gap of more than
// one day resets the streak to 1. Returns the new streak value.
func (r *Repo) UpdateDailyStreak(ctx context.Context, userID string) (int, error) {
	var newStreak int
	err := r.pool.QueryRow(ctx, `
		WITH today_count AS (
			SELECT COUNT(*) AS cnt
			FROM xp_events
			WHERE user_id = $1 AND created_at::date = current_date
		),
		had_yesterday AS (
			SELECT EXISTS(
				SELECT 1 FROM xp_events
				WHERE user_id = $1 AND created_at::date = current_date - 1
			) AS val
		)
		UPDATE user_stats
		SET current_streak_days = CASE
			WHEN (SELECT cnt FROM today_count) > 1      THEN current_streak_days
			WHEN (SELECT val FROM had_yesterday)        THEN current_streak_days + 1
			ELSE 1
		END,
		updated_at = now()
		WHERE user_id = $1
		RETURNING current_streak_days`,
		userID,
	).Scan(&newStreak)
	if err != nil {
		return 0, fmt.Errorf("rewards: update daily streak: %w", err)
	}
	return newStreak, nil
}

// ─── PostgreSQL: badges ───────────────────────────────────────────────────────

// GetAllDefinitions returns the full badge catalog.
func (r *Repo) GetAllDefinitions(ctx context.Context) ([]RewardDefinition, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, slug, name, description, icon, badge_tier, xp_value,
		       trigger_event, trigger_threshold, created_at
		FROM reward_definitions ORDER BY badge_tier, trigger_threshold`)
	if err != nil {
		return nil, fmt.Errorf("rewards: list definitions: %w", err)
	}
	defer rows.Close()
	return scanDefinitions(rows)
}

// GetDefinitionsByEvent returns definitions for a specific trigger event.
func (r *Repo) GetDefinitionsByEvent(ctx context.Context, event string) ([]RewardDefinition, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, slug, name, description, icon, badge_tier, xp_value,
		       trigger_event, trigger_threshold, created_at
		FROM reward_definitions WHERE trigger_event = $1`, event)
	if err != nil {
		return nil, fmt.Errorf("rewards: definitions by event: %w", err)
	}
	defer rows.Close()
	return scanDefinitions(rows)
}

func scanDefinitions(rows pgx.Rows) ([]RewardDefinition, error) {
	var defs []RewardDefinition
	for rows.Next() {
		var d RewardDefinition
		if err := rows.Scan(&d.ID, &d.Slug, &d.Name, &d.Description, &d.Icon,
			&d.BadgeTier, &d.XPValue, &d.TriggerEvent, &d.TriggerThreshold, &d.CreatedAt); err != nil {
			return nil, err
		}
		defs = append(defs, d)
	}
	return defs, rows.Err()
}

// GetEarnedSlugs returns all badge slugs already earned by a user.
func (r *Repo) GetEarnedSlugs(ctx context.Context, userID string) ([]string, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT rd.slug FROM user_achievements ua
		JOIN reward_definitions rd ON rd.id = ua.reward_definition_id
		WHERE ua.user_id = $1`, userID)
	if err != nil {
		return nil, fmt.Errorf("rewards: earned slugs: %w", err)
	}
	defer rows.Close()
	var slugs []string
	for rows.Next() {
		var s string
		if err := rows.Scan(&s); err != nil {
			return nil, err
		}
		slugs = append(slugs, s)
	}
	return slugs, rows.Err()
}

// GrantAchievement inserts a user_achievement row.
func (r *Repo) GrantAchievement(ctx context.Context, userID, orgID, defID string) (UserAchievement, error) {
	var ua UserAchievement
	var storedOrgID *string
	if orgID != "" {
		storedOrgID = &orgID
	}
	ua.UserID = userID
	ua.OrgID = storedOrgID
	err := r.pool.QueryRow(ctx, `
		INSERT INTO user_achievements (user_id, reward_definition_id, org_id)
		VALUES ($1, $2, $3)
		ON CONFLICT DO NOTHING
		RETURNING id, earned_at`,
		userID, defID, storedOrgID,
	).Scan(&ua.ID, &ua.EarnedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return UserAchievement{}, nil // already earned — ON CONFLICT returned no row
		}
		return UserAchievement{}, fmt.Errorf("rewards: grant achievement: %w", err)
	}
	return ua, nil
}

// GetCountForBadgeCheck returns the current stat value for a given trigger event.
func (r *Repo) GetCountForBadgeCheck(ctx context.Context, userID, event string) (int, error) {
	var col string
	switch event {
	case "problem_solved":
		col = "problems_solved"
	case "course_completed":
		col = "courses_completed"
	case "certificate_earned":
		col = "certificates_earned"
	case "streak_milestone":
		col = "current_streak_days"
	case "quiz_perfect", "quiz_passed":
		var count int
		err := r.pool.QueryRow(ctx,
			`SELECT COUNT(*) FROM xp_events WHERE user_id = $1 AND reason = $2`,
			userID, event).Scan(&count)
		return count, err
	default:
		return 0, nil
	}
	var count int
	err := r.pool.QueryRow(ctx,
		fmt.Sprintf(`SELECT COALESCE(%s, 0) FROM user_stats WHERE user_id = $1`, col),
		userID).Scan(&count)
	if err != nil {
		return 0, err
	}
	return count, nil
}

// CheckAndGrantBadges checks all badge definitions for the given event against the
// user's current stat and grants any newly earned badges. Returns only newly granted ones.
func (r *Repo) CheckAndGrantBadges(ctx context.Context, userID, orgID, event string) ([]UserAchievement, error) {
	defs, err := r.GetDefinitionsByEvent(ctx, event)
	if err != nil || len(defs) == 0 {
		return nil, err
	}
	count, err := r.GetCountForBadgeCheck(ctx, userID, event)
	if err != nil {
		return nil, err
	}
	earned, err := r.GetEarnedSlugs(ctx, userID)
	if err != nil {
		return nil, err
	}
	earnedSet := make(map[string]bool, len(earned))
	for _, s := range earned {
		earnedSet[s] = true
	}

	var newBadges []UserAchievement
	for _, def := range defs {
		if earnedSet[def.Slug] || count < def.TriggerThreshold {
			continue
		}
		ua, grantErr := r.GrantAchievement(ctx, userID, orgID, def.ID)
		if grantErr != nil {
			slog.Error("rewards: grant badge", "slug", def.Slug, "user", userID, "err", grantErr)
			continue
		}
		if ua.ID == "" {
			continue // already earned (ON CONFLICT DO NOTHING returned nothing)
		}
		ua.Definition = def
		newBadges = append(newBadges, ua)
	}
	return newBadges, nil
}

// CheckAndGrantLevelBadges checks and grants level_reached badges for a specific level.
func (r *Repo) CheckAndGrantLevelBadges(ctx context.Context, userID, orgID string, level int) ([]UserAchievement, error) {
	defs, err := r.GetDefinitionsByEvent(ctx, "level_reached")
	if err != nil || len(defs) == 0 {
		return nil, err
	}
	earned, err := r.GetEarnedSlugs(ctx, userID)
	if err != nil {
		return nil, err
	}
	earnedSet := make(map[string]bool, len(earned))
	for _, s := range earned {
		earnedSet[s] = true
	}

	var newBadges []UserAchievement
	for _, def := range defs {
		if earnedSet[def.Slug] || level < def.TriggerThreshold {
			continue
		}
		ua, grantErr := r.GrantAchievement(ctx, userID, orgID, def.ID)
		if grantErr != nil || ua.ID == "" {
			continue
		}
		ua.Definition = def
		newBadges = append(newBadges, ua)
	}
	return newBadges, nil
}

// ─── PostgreSQL: user profile ─────────────────────────────────────────────────

// GetUserRewardProfile returns the full XP + achievement profile for a user.
func (r *Repo) GetUserRewardProfile(ctx context.Context, userID string) (UserRewardProfile, error) {
	var profile UserRewardProfile
	var totalXP, level int
	var levelName string

	err := r.pool.QueryRow(ctx, `
		SELECT COALESCE(total_xp, 0), COALESCE(xp_level, 1), COALESCE(xp_level_name, 'Apprentice')
		FROM user_stats WHERE user_id = $1`, userID).Scan(&totalXP, &level, &levelName)
	if err != nil && err != pgx.ErrNoRows {
		return profile, fmt.Errorf("rewards: get user stats: %w", err)
	}
	profile.TotalXP = totalXP
	profile.Level = ComputeLevel(totalXP)

	rows, err := r.pool.Query(ctx, `
		SELECT ua.id, ua.user_id, ua.org_id, ua.earned_at,
		       rd.id, rd.slug, rd.name, rd.description, rd.icon,
		       rd.badge_tier, rd.xp_value, rd.trigger_event, rd.trigger_threshold, rd.created_at
		FROM user_achievements ua
		JOIN reward_definitions rd ON rd.id = ua.reward_definition_id
		WHERE ua.user_id = $1
		ORDER BY ua.earned_at DESC`, userID)
	if err != nil {
		return profile, fmt.Errorf("rewards: list achievements: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var ua UserAchievement
		if err := rows.Scan(
			&ua.ID, &ua.UserID, &ua.OrgID, &ua.EarnedAt,
			&ua.Definition.ID, &ua.Definition.Slug, &ua.Definition.Name, &ua.Definition.Description,
			&ua.Definition.Icon, &ua.Definition.BadgeTier, &ua.Definition.XPValue,
			&ua.Definition.TriggerEvent, &ua.Definition.TriggerThreshold, &ua.Definition.CreatedAt,
		); err != nil {
			return profile, err
		}
		profile.Achievements = append(profile.Achievements, ua)
	}
	if err := rows.Err(); err != nil {
		return profile, err
	}
	if profile.Achievements == nil {
		profile.Achievements = []UserAchievement{}
	}

	xpRows, err := r.pool.Query(ctx, `
		SELECT id, xp_amount, reason, reference_id::text, reference_type, created_at
		FROM xp_events WHERE user_id = $1
		ORDER BY created_at DESC LIMIT 20`, userID)
	if err != nil {
		return profile, fmt.Errorf("rewards: list xp events: %w", err)
	}
	defer xpRows.Close()
	for xpRows.Next() {
		var e XPEvent
		if err := xpRows.Scan(&e.ID, &e.XPAmount, &e.Reason, &e.ReferenceID, &e.ReferenceType, &e.CreatedAt); err != nil {
			return profile, err
		}
		profile.RecentXP = append(profile.RecentXP, e)
	}
	if profile.RecentXP == nil {
		profile.RecentXP = []XPEvent{}
	}

	return profile, xpRows.Err()
}

// ─── Redis: sorted sets ───────────────────────────────────────────────────────

// IncrementSortedSets updates all applicable leaderboard sorted sets for one award event.
func (r *Repo) IncrementSortedSets(ctx context.Context, req AwardXPRequest, xp int) error {
	pipe := r.rdb.Pipeline()

	pipe.ZIncrBy(ctx, "leaderboard:global", float64(xp), req.UserID)

	if req.OrgID != "" {
		pipe.ZIncrBy(ctx, "leaderboard:org:"+req.OrgID, float64(xp), req.UserID)

		switch req.Reason {
		case "problem_solved":
			pipe.ZIncrBy(ctx, "leaderboard:feature:org:"+req.OrgID+":problems", float64(xp), req.UserID)
		case "quiz_passed", "quiz_perfect":
			pipe.ZIncrBy(ctx, "leaderboard:feature:org:"+req.OrgID+":quizzes", float64(xp), req.UserID)
		}
	}
	if req.BatchID != nil && *req.BatchID != "" {
		pipe.ZIncrBy(ctx, "leaderboard:batch:"+*req.BatchID, float64(xp), req.UserID)
	}
	if req.CourseID != nil && *req.CourseID != "" {
		pipe.ZIncrBy(ctx, "leaderboard:course:"+*req.CourseID, float64(xp), req.UserID)
	}

	_, err := pipe.Exec(ctx)
	if err != nil {
		return fmt.Errorf("rewards: increment sorted sets: %w", err)
	}
	return nil
}

// GetLeaderboard fetches a page from the sorted set and joins user display data.
// Falls back to PostgreSQL for users missing from the profile hash cache.
func (r *Repo) GetLeaderboard(ctx context.Context, key string, limit, offset int) ([]LeaderboardEntry, error) {
	start := int64(offset)
	stop := int64(offset + limit - 1)

	zs, err := r.rdb.ZRevRangeWithScores(ctx, key, start, stop).Result()
	if err == redis.Nil || len(zs) == 0 {
		// Sorted set empty or missing — fall back to PostgreSQL.
		return r.leaderboardFromDB(ctx, key, limit, offset)
	}
	if err != nil {
		return nil, fmt.Errorf("rewards: zrevrange: %w", err)
	}

	entries := make([]LeaderboardEntry, 0, len(zs))
	for i, z := range zs {
		userID := z.Member.(string)
		entry := LeaderboardEntry{
			Rank:    offset + i + 1,
			UserID:  userID,
			TotalXP: int(z.Score),
		}

		profile, cacheErr := r.getUserProfileCache(ctx, userID)
		if cacheErr != nil || profile == nil {
			profile, cacheErr = r.fetchAndCacheUserProfile(ctx, userID)
			if cacheErr != nil {
				entry.Name = "Unknown"
			}
		}
		if profile != nil {
			entry.Name = profile.Name
			entry.AvatarURL = profile.AvatarURL
			entry.Level = profile.Level
			entry.LevelName = profile.LevelName
		}
		entries = append(entries, entry)
	}
	return entries, nil
}

type cachedUserProfile struct {
	Name      string
	AvatarURL *string
	Level     int
	LevelName string
}

func (r *Repo) getUserProfileCache(ctx context.Context, userID string) (*cachedUserProfile, error) {
	m, err := r.rdb.HGetAll(ctx, "user_lb_profile:"+userID).Result()
	if err != nil || len(m) == 0 {
		return nil, nil
	}
	p := &cachedUserProfile{Name: m["name"], LevelName: m["level_name"]}
	if v, ok := m["avatar_url"]; ok && v != "" {
		p.AvatarURL = &v
	}
	if v, ok := m["level"]; ok {
		p.Level, _ = strconv.Atoi(v)
	}
	return p, nil
}

func (r *Repo) fetchAndCacheUserProfile(ctx context.Context, userID string) (*cachedUserProfile, error) {
	var name string
	var avatarURL *string
	var totalXP, level int
	var levelName string

	err := r.pool.QueryRow(ctx, `
		SELECT u.name, u.avatar_url,
		       COALESCE(us.total_xp, 0), COALESCE(us.xp_level, 1), COALESCE(us.xp_level_name, 'Apprentice')
		FROM users u
		LEFT JOIN user_stats us ON us.user_id = u.id
		WHERE u.id = $1`, userID).Scan(&name, &avatarURL, &totalXP, &level, &levelName)
	if err != nil {
		return nil, fmt.Errorf("rewards: fetch user profile: %w", err)
	}

	p := &cachedUserProfile{Name: name, AvatarURL: avatarURL, Level: level, LevelName: levelName}
	r.SetUserProfileCache(ctx, userID, name, avatarURL, level, levelName)
	return p, nil
}

// SetUserProfileCache writes the user's display data to the Redis hash with a 10-min TTL.
func (r *Repo) SetUserProfileCache(ctx context.Context, userID, name string, avatarURL *string, level int, levelName string) {
	key := "user_lb_profile:" + userID
	avatarStr := ""
	if avatarURL != nil {
		avatarStr = *avatarURL
	}
	pipe := r.rdb.Pipeline()
	pipe.HSet(ctx, key,
		"name", name,
		"avatar_url", avatarStr,
		"level", strconv.Itoa(level),
		"level_name", levelName,
	)
	pipe.Expire(ctx, key, userProfileTTL)
	if _, err := pipe.Exec(ctx); err != nil {
		slog.Error("rewards: set user profile cache", "user", userID, "err", err)
	}
}

// GetUserRank returns the 0-based rank of a user in a sorted set and their score.
func (r *Repo) GetUserRank(ctx context.Context, key, userID string) (rank int64, xp float64, err error) {
	rank, err = r.rdb.ZRevRank(ctx, key, userID).Result()
	if err == redis.Nil {
		return -1, 0, nil
	}
	if err != nil {
		return -1, 0, fmt.Errorf("rewards: zrevrank: %w", err)
	}
	xp, err = r.rdb.ZScore(ctx, key, userID).Result()
	if err != nil {
		xp = 0
	}
	return rank, xp, nil
}

// ─── PostgreSQL: fallback leaderboard ────────────────────────────────────────

// leaderboardFromDB builds a leaderboard page directly from the DB when Redis is cold.
func (r *Repo) leaderboardFromDB(ctx context.Context, key string, limit, offset int) ([]LeaderboardEntry, error) {
	// Determine scope from the key
	scope, scopeID, featureType := parseLBKey(key)
	var query string
	var args []any

	switch scope {
	case "global":
		query = `
			SELECT u.id, u.name, u.avatar_url,
			       COALESCE(us.total_xp, 0), COALESCE(us.xp_level, 1), COALESCE(us.xp_level_name, 'Apprentice')
			FROM users u
			LEFT JOIN user_stats us ON us.user_id = u.id
			WHERE COALESCE(us.total_xp, 0) > 0
			ORDER BY us.total_xp DESC NULLS LAST
			LIMIT $1 OFFSET $2`
		args = []any{limit, offset}
	case "org":
		query = `
			SELECT u.id, u.name, u.avatar_url,
			       COALESCE(us.total_xp, 0), COALESCE(us.xp_level, 1), COALESCE(us.xp_level_name, 'Apprentice')
			FROM org_members om
			JOIN users u ON u.id = om.user_id
			LEFT JOIN user_stats us ON us.user_id = u.id
			WHERE om.org_id = $1 AND om.status = 'active'
			ORDER BY us.total_xp DESC NULLS LAST
			LIMIT $2 OFFSET $3`
		args = []any{scopeID, limit, offset}
	case "batch":
		query = `
			SELECT u.id, u.name, u.avatar_url,
			       COALESCE(SUM(xe.xp_amount), 0)::int AS total_xp,
			       COALESCE(us.xp_level, 1), COALESCE(us.xp_level_name, 'Apprentice')
			FROM batch_members bm
			JOIN users u ON u.id = bm.user_id
			LEFT JOIN xp_events xe ON xe.user_id = u.id AND xe.batch_id = bm.batch_id
			LEFT JOIN user_stats us ON us.user_id = u.id
			WHERE bm.batch_id = $1
			GROUP BY u.id, u.name, u.avatar_url, us.xp_level, us.xp_level_name
			ORDER BY total_xp DESC
			LIMIT $2 OFFSET $3`
		args = []any{scopeID, limit, offset}
	case "course":
		query = `
			SELECT u.id, u.name, u.avatar_url,
			       COALESCE(SUM(xe.xp_amount), 0)::int AS total_xp,
			       COALESCE(us.xp_level, 1), COALESCE(us.xp_level_name, 'Apprentice')
			FROM enrollments e
			JOIN users u ON u.id = e.user_id
			LEFT JOIN xp_events xe ON xe.user_id = u.id AND xe.course_id = e.course_id
			LEFT JOIN user_stats us ON us.user_id = u.id
			WHERE e.course_id = $1
			GROUP BY u.id, u.name, u.avatar_url, us.xp_level, us.xp_level_name
			ORDER BY total_xp DESC
			LIMIT $2 OFFSET $3`
		args = []any{scopeID, limit, offset}
	case "feature":
		switch featureType {
		case "problems":
			query = `
				SELECT u.id, u.name, u.avatar_url,
				       COALESCE(SUM(xe.xp_amount), 0)::int AS total_xp,
				       COALESCE(us.xp_level, 1), COALESCE(us.xp_level_name, 'Apprentice')
				FROM xp_events xe
				JOIN users u ON u.id = xe.user_id
				LEFT JOIN user_stats us ON us.user_id = u.id
				WHERE xe.org_id = $1 AND xe.reason = 'problem_solved'
				GROUP BY u.id, u.name, u.avatar_url, us.xp_level, us.xp_level_name
				ORDER BY total_xp DESC
				LIMIT $2 OFFSET $3`
			args = []any{scopeID, limit, offset}
		case "quizzes":
			// Matches IncrementSortedSets: both quiz_passed and quiz_perfect XP count.
			query = `
				SELECT u.id, u.name, u.avatar_url,
				       COALESCE(SUM(xe.xp_amount), 0)::int AS total_xp,
				       COALESCE(us.xp_level, 1), COALESCE(us.xp_level_name, 'Apprentice')
				FROM xp_events xe
				JOIN users u ON u.id = xe.user_id
				LEFT JOIN user_stats us ON us.user_id = u.id
				WHERE xe.org_id = $1 AND xe.reason IN ('quiz_passed', 'quiz_perfect')
				GROUP BY u.id, u.name, u.avatar_url, us.xp_level, us.xp_level_name
				ORDER BY total_xp DESC
				LIMIT $2 OFFSET $3`
			args = []any{scopeID, limit, offset}
		default:
			return []LeaderboardEntry{}, nil
		}
	default:
		return []LeaderboardEntry{}, nil
	}

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("rewards: leaderboard db fallback: %w", err)
	}
	defer rows.Close()

	var entries []LeaderboardEntry
	rank := offset + 1
	for rows.Next() {
		var e LeaderboardEntry
		if err := rows.Scan(&e.UserID, &e.Name, &e.AvatarURL, &e.TotalXP, &e.Level, &e.LevelName); err != nil {
			return nil, err
		}
		e.Rank = rank
		rank++
		entries = append(entries, e)
	}
	if entries == nil {
		entries = []LeaderboardEntry{}
	}
	return entries, rows.Err()
}

// ─── Leaderboard warm-up ─────────────────────────────────────────────────────

// WarmLeaderboards rebuilds all Redis sorted sets from xp_events on startup.
// Runs in a background goroutine — never blocks the server start.
func (r *Repo) WarmLeaderboards(ctx context.Context) {
	slog.Info("rewards: warming leaderboards")

	// Global
	if err := r.rebuildGlobal(ctx); err != nil {
		slog.Error("rewards: warm global leaderboard", "err", err)
	}

	// Per-org
	orgIDs, err := r.listActiveOrgIDs(ctx)
	if err != nil {
		slog.Error("rewards: warm org leaderboards: list orgs", "err", err)
		return
	}
	for _, id := range orgIDs {
		if err := r.rebuildScope(ctx, "leaderboard:org:"+id, "org", id, ""); err != nil {
			slog.Error("rewards: warm org leaderboard", "org", id, "err", err)
		}
	}

	// Per-batch
	batchIDs, err := r.listActiveBatchIDs(ctx)
	if err != nil {
		slog.Error("rewards: warm batch leaderboards: list batches", "err", err)
		return
	}
	for _, id := range batchIDs {
		if err := r.rebuildScope(ctx, "leaderboard:batch:"+id, "batch", id, ""); err != nil {
			slog.Error("rewards: warm batch leaderboard", "batch", id, "err", err)
		}
	}

	// Feature boards (problems / quizzes) per org
	for _, id := range orgIDs {
		if err := r.rebuildFeatureBoard(ctx, id, "problems", "problem_solved"); err != nil {
			slog.Error("rewards: warm problems leaderboard", "org", id, "err", err)
		}
		if err := r.rebuildFeatureBoard(ctx, id, "quizzes", "quiz_passed", "quiz_perfect"); err != nil {
			slog.Error("rewards: warm quizzes leaderboard", "org", id, "err", err)
		}
	}

	slog.Info("rewards: leaderboard warm-up complete")
}

func (r *Repo) rebuildGlobal(ctx context.Context) error {
	rows, err := r.pool.Query(ctx, `SELECT user_id, total_xp FROM user_stats WHERE total_xp > 0`)
	if err != nil {
		return err
	}
	defer rows.Close()
	pipe := r.rdb.Pipeline()
	for rows.Next() {
		var userID string
		var totalXP int
		if err := rows.Scan(&userID, &totalXP); err != nil {
			return err
		}
		pipe.ZAdd(ctx, "leaderboard:global", redis.Z{Score: float64(totalXP), Member: userID})
	}
	_, err = pipe.Exec(ctx)
	return err
}

func (r *Repo) rebuildScope(ctx context.Context, key, scope, scopeID, _ string) error {
	var col string
	switch scope {
	case "org":
		col = "org_id"
	case "batch":
		col = "batch_id"
	case "course":
		col = "course_id"
	default:
		return nil
	}
	rows, err := r.pool.Query(ctx, fmt.Sprintf(`
		SELECT user_id, SUM(xp_amount)::int FROM xp_events WHERE %s = $1 GROUP BY user_id`, col), scopeID)
	if err != nil {
		return err
	}
	defer rows.Close()
	pipe := r.rdb.Pipeline()
	for rows.Next() {
		var userID string
		var xp int
		if err := rows.Scan(&userID, &xp); err != nil {
			return err
		}
		pipe.ZAdd(ctx, key, redis.Z{Score: float64(xp), Member: userID})
	}
	_, err = pipe.Exec(ctx)
	return err
}

func (r *Repo) listActiveOrgIDs(ctx context.Context) ([]string, error) {
	rows, err := r.pool.Query(ctx, `SELECT id FROM organizations WHERE status = 'active'`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

func (r *Repo) listActiveBatchIDs(ctx context.Context) ([]string, error) {
	rows, err := r.pool.Query(ctx, `SELECT id FROM batches WHERE status = 'active'`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// rebuildFeatureBoard rebuilds a feature-scoped leaderboard sorted set from xp_events.
// reasons vararg supports one or more reason values (e.g. "quiz_passed", "quiz_perfect").
func (r *Repo) rebuildFeatureBoard(ctx context.Context, orgID, featureType string, reasons ...string) error {
	key := "leaderboard:feature:org:" + orgID + ":" + featureType
	placeholders := make([]string, len(reasons))
	args := make([]any, len(reasons)+1)
	args[0] = orgID
	for i, reason := range reasons {
		placeholders[i] = fmt.Sprintf("$%d", i+2)
		args[i+1] = reason
	}
	inClause := "(" + joinStrings(placeholders, ",") + ")"
	rows, err := r.pool.Query(ctx, fmt.Sprintf(`
		SELECT user_id, SUM(xp_amount)::int FROM xp_events
		WHERE org_id = $1 AND reason IN %s
		GROUP BY user_id`, inClause), args...)
	if err != nil {
		return fmt.Errorf("rewards: rebuild feature board %s: %w", key, err)
	}
	defer rows.Close()
	pipe := r.rdb.Pipeline()
	for rows.Next() {
		var userID string
		var xp int
		if err := rows.Scan(&userID, &xp); err != nil {
			return err
		}
		pipe.ZAdd(ctx, key, redis.Z{Score: float64(xp), Member: userID})
	}
	if err := rows.Err(); err != nil {
		return err
	}
	_, err = pipe.Exec(ctx)
	return err
}

func joinStrings(ss []string, sep string) string {
	result := ""
	for i, s := range ss {
		if i > 0 {
			result += sep
		}
		result += s
	}
	return result
}

// parseLBKey decodes a leaderboard Redis key into (scope, scopeID, featureType).
// Examples:
//
//	"leaderboard:global"               → ("global", "", "")
//	"leaderboard:org:abc123"           → ("org", "abc123", "")
//	"leaderboard:batch:xyz"            → ("batch", "xyz", "")
//	"leaderboard:feature:org:abc:problems" → ("feature", "abc", "problems")
func parseLBKey(key string) (scope, scopeID, featureType string) {
	const (
		pfxGlobal  = "leaderboard:global"
		pfxOrg     = "leaderboard:org:"        // 16 chars
		pfxBatch   = "leaderboard:batch:"      // 18 chars
		pfxCourse  = "leaderboard:course:"     // 19 chars
		pfxFeature = "leaderboard:feature:org:" // 24 chars
	)
	switch {
	case key == pfxGlobal:
		return "global", "", ""
	case len(key) > len(pfxOrg) && key[:len(pfxOrg)] == pfxOrg:
		return "org", key[len(pfxOrg):], ""
	case len(key) > len(pfxBatch) && key[:len(pfxBatch)] == pfxBatch:
		return "batch", key[len(pfxBatch):], ""
	case len(key) > len(pfxCourse) && key[:len(pfxCourse)] == pfxCourse:
		return "course", key[len(pfxCourse):], ""
	case len(key) > len(pfxFeature) && key[:len(pfxFeature)] == pfxFeature:
		rest := key[len(pfxFeature):]
		for i := len(rest) - 1; i >= 0; i-- {
			if rest[i] == ':' {
				return "feature", rest[:i], rest[i+1:]
			}
		}
	}
	return "", "", ""
}
