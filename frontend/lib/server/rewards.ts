import "server-only";
import { apiGet } from "@/lib/server/api";

export interface UserLevel {
  level: number;
  name: string;
  min_xp: number;
  max_xp: number;
  progress_pct: number;
}

export interface RewardDefinition {
  id: string;
  slug: string;
  name: string;
  description: string;
  icon: string;
  badge_tier: "bronze" | "silver" | "gold" | "platinum";
  xp_value: number;
  trigger_event: string;
  trigger_threshold: number;
  created_at: string;
}

export interface UserAchievement {
  id: string;
  user_id: string;
  definition: RewardDefinition;
  org_id?: string;
  earned_at: string;
}

export interface XPEvent {
  id: string;
  xp_amount: number;
  reason: string;
  reference_id?: string;
  reference_type?: string;
  created_at: string;
}

export interface UserRewardProfile {
  total_xp: number;
  level: UserLevel;
  achievements: UserAchievement[];
  recent_xp: XPEvent[];
}

export interface LeaderboardEntry {
  rank: number;
  user_id: string;
  name: string;
  avatar_url?: string;
  total_xp: number;
  level: number;
  level_name: string;
}

export interface LeaderboardResponse {
  entries: LeaderboardEntry[];
  me?: { rank: number; xp: number };
}

export interface MyRankResponse {
  rank: number;
  xp: number;
  scope: string;
}

// AwardResult is piggybacked on assessment and course API responses.
export interface AwardResult {
  xp_gained: number;
  new_level?: UserLevel;
  new_achievements: UserAchievement[];
}

export async function getMyRewardProfile(): Promise<UserRewardProfile | null> {
  try {
    return await apiGet<UserRewardProfile>("/api/rewards/me");
  } catch {
    return null;
  }
}

export async function getLeaderboard(
  scope: string,
  scopeId?: string,
  featureType?: string,
  limit = 20,
  offset = 0,
): Promise<LeaderboardResponse | null> {
  try {
    const params = new URLSearchParams({ scope, limit: String(limit), offset: String(offset) });
    if (scopeId) params.set("scope_id", scopeId);
    if (featureType) params.set("feature_type", featureType);
    return await apiGet<LeaderboardResponse>(`/api/rewards/leaderboard?${params}`);
  } catch {
    return null;
  }
}

export async function getMyRank(
  scope: string,
  scopeId?: string,
  featureType?: string,
): Promise<MyRankResponse | null> {
  try {
    const params = new URLSearchParams({ scope });
    if (scopeId) params.set("scope_id", scopeId);
    if (featureType) params.set("feature_type", featureType);
    return await apiGet<MyRankResponse>(`/api/rewards/leaderboard/me?${params}`);
  } catch {
    return null;
  }
}
