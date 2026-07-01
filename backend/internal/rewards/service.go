package rewards

import (
	"context"
	"log/slog"
)

// Service implements all business logic for the rewards domain.
type Service struct {
	repo *Repo
}

func NewService(repo *Repo) *Service {
	return &Service{repo: repo}
}

// WarmLeaderboards rebuilds Redis sorted sets from PostgreSQL on startup.
// Call in a goroutine — it never blocks.
func (s *Service) WarmLeaderboards(ctx context.Context) {
	s.repo.WarmLeaderboards(ctx)
}

// AwardXP awards XP for an event, updates the leaderboard, recomputes the
// user's level, and checks for newly earned badges. Always returns a valid
// AwardResult — reward failures are logged but never propagated to the caller,
// so a reward bug can never break the primary action.
func (s *Service) AwardXP(ctx context.Context, req AwardXPRequest) AwardResult {
	empty := AwardResult{NewAchievements: []UserAchievement{}}
	if req.XP <= 0 || req.UserID == "" {
		return empty
	}

	// 1. Persist XP event and increment user_stats.total_xp.
	newTotal, oldLevel, err := s.repo.AddXPAndGetTotal(ctx, req)
	if err != nil {
		slog.Error("rewards: add xp", "user", req.UserID, "reason", req.Reason, "err", err)
		return empty
	}

	// 2. Compute new level and persist if changed.
	newLevel := ComputeLevel(newTotal)
	var levelUp *UserLevel
	if newLevel.Level > oldLevel {
		if updErr := s.repo.UpdateUserLevel(ctx, req.UserID, newLevel); updErr != nil {
			slog.Error("rewards: update level", "user", req.UserID, "err", updErr)
		} else {
			levelUp = &newLevel
		}
	}

	// 3. Update Redis sorted sets.
	if incrErr := s.repo.IncrementSortedSets(ctx, req, req.XP); incrErr != nil {
		slog.Error("rewards: sorted sets", "user", req.UserID, "err", incrErr)
	}

	// 4. Refresh user profile hash in Redis.
	if p, fetchErr := s.repo.fetchAndCacheUserProfile(ctx, req.UserID); fetchErr != nil {
		slog.Error("rewards: refresh profile cache", "user", req.UserID, "err", fetchErr)
	} else if p != nil {
		s.repo.SetUserProfileCache(ctx, req.UserID, p.Name, p.AvatarURL, newLevel.Level, newLevel.Name)
	}

	// 5. Check and grant event-specific badges.
	var allBadges []UserAchievement
	badges, badgeErr := s.repo.CheckAndGrantBadges(ctx, req.UserID, req.OrgID, req.Reason)
	if badgeErr != nil {
		slog.Error("rewards: check badges", "user", req.UserID, "event", req.Reason, "err", badgeErr)
	} else {
		allBadges = append(allBadges, badges...)
	}

	// 6. Check level-up badges if the user just levelled up.
	if levelUp != nil {
		levelBadges, lbErr := s.repo.CheckAndGrantLevelBadges(ctx, req.UserID, req.OrgID, levelUp.Level)
		if lbErr != nil {
			slog.Error("rewards: check level badges", "user", req.UserID, "err", lbErr)
		} else {
			allBadges = append(allBadges, levelBadges...)
		}
	}

	if allBadges == nil {
		allBadges = []UserAchievement{}
	}
	return AwardResult{XPGained: req.XP, NewLevel: levelUp, NewAchievements: allBadges}
}

// CheckStreakMilestones awards bonus XP and grants badges when a streak threshold
// is crossed. Safe to call after every streak increment — only fires on milestones.
func (s *Service) CheckStreakMilestones(ctx context.Context, userID, orgID string, newStreakDays int) AwardResult {
	empty := AwardResult{NewAchievements: []UserAchievement{}}

	xp, ok := StreakMilestones[newStreakDays]
	if !ok {
		return empty
	}
	reason := "streak_milestone"
	refType := "streak"
	return s.AwardXP(ctx, AwardXPRequest{
		UserID:  userID,
		OrgID:   orgID,
		Reason:  reason,
		RefType: &refType,
		XP:      xp,
	})
}

// UpdateStreakAndCheckMilestones updates the daily streak counter for a user and
// fires milestone rewards (XP + badges) when a threshold is first crossed.
// Non-fatal: errors are logged but never returned.
func (s *Service) UpdateStreakAndCheckMilestones(ctx context.Context, userID, orgID string) AwardResult {
	newStreak, err := s.repo.UpdateDailyStreak(ctx, userID)
	if err != nil {
		slog.Error("rewards: update daily streak", "user", userID, "err", err)
		return AwardResult{NewAchievements: []UserAchievement{}}
	}
	return s.CheckStreakMilestones(ctx, userID, orgID, newStreak)
}

// GetUserRewardProfile returns the full XP, level, and achievement profile for a user.
func (s *Service) GetUserRewardProfile(ctx context.Context, userID string) (UserRewardProfile, error) {
	return s.repo.GetUserRewardProfile(ctx, userID)
}

// GetLeaderboard returns a paginated leaderboard for the given scope.
// key is a Redis sorted-set key (e.g. "leaderboard:org:{id}").
func (s *Service) GetLeaderboard(ctx context.Context, key string, limit, offset int) ([]LeaderboardEntry, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	return s.repo.GetLeaderboard(ctx, key, limit, offset)
}

// GetUserRank returns the 1-based rank and XP score of a user in a leaderboard scope.
func (s *Service) GetUserRank(ctx context.Context, key, userID string) (rank int64, xp float64, err error) {
	r, score, err := s.repo.GetUserRank(ctx, key, userID)
	if err != nil {
		return -1, 0, err
	}
	if r == -1 {
		return -1, 0, nil // not ranked
	}
	return r + 1, score, nil // convert 0-based to 1-based
}

// ListDefinitions returns all badge/achievement definitions.
func (s *Service) ListDefinitions(ctx context.Context) ([]RewardDefinition, error) {
	return s.repo.GetAllDefinitions(ctx)
}
