"use client";

import { toast } from "sonner";
import type { AwardResult } from "@/lib/server/rewards";

const TIER_EMOJI: Record<string, string> = {
  bronze:   "🥉",
  silver:   "🥈",
  gold:     "🥇",
  platinum: "💎",
};

export function showRewardToasts(result: AwardResult) {
  if (!result) return;

  if (result.xp_gained > 0) {
    toast.success(`+${result.xp_gained} XP`, {
      description: "Keep it up!",
      duration: 3500,
    });
  }

  if (result.new_level) {
    toast.success(`Level Up! You're now ${result.new_level.name}`, {
      description: `Reached Level ${result.new_level.level} — ${result.new_level.min_xp.toLocaleString()} XP milestone`,
      duration: 6000,
    });
  }

  for (const achievement of result.new_achievements ?? []) {
    const def = achievement.definition;
    const emoji = TIER_EMOJI[def.badge_tier] ?? "🏆";
    toast(`${emoji} ${def.name}`, {
      description: def.description,
      duration: 5000,
    });
  }
}
