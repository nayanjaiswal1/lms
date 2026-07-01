"use client";

import { cn } from "@/lib/utils";
import type { UserLevel } from "@/lib/server/rewards";

interface XPProgressBarProps {
  totalXP: number;
  level: UserLevel;
  className?: string;
  compact?: boolean;
}

const TIER_COLORS: Record<number, string> = {
  1: "bg-muted text-muted-foreground",
  2: "bg-primary/10 text-primary",
  3: "bg-primary/15 text-primary",
  4: "bg-ai/10 text-ai",
  5: "bg-ai/15 text-ai",
  6: "bg-ai/20 text-ai",
  7: "bg-ai/25 text-ai",
  8: "bg-ai/30 text-ai",
  9: "bg-ai/35 text-ai",
  10: "bg-ai/40 text-ai",
};

export function XPProgressBar({ totalXP, level, className, compact = false }: XPProgressBarProps) {
  const pct = Math.min(100, Math.max(0, level.progress_pct));
  const isMaxLevel = level.max_xp === -1;
  const tierColor = TIER_COLORS[level.level] ?? TIER_COLORS[1];

  const xpLabel = isMaxLevel
    ? `${totalXP.toLocaleString()} XP`
    : `${totalXP.toLocaleString()} / ${level.max_xp.toLocaleString()} XP`;

  if (compact) {
    return (
      <div className={cn("flex flex-col gap-1", className)}>
        <div className="flex items-center justify-between gap-2">
          <span className={cn("rounded px-1.5 py-0.5 text-xs font-semibold", tierColor)}>
            Lv.{level.level}
          </span>
          <span className="text-xs text-muted-foreground tabular-nums">{xpLabel}</span>
        </div>
        <div className="progress-track h-1.5">
          <div
            className="progress-fill h-full transition-all duration-500"
            style={{ width: `${pct}%` }}
            aria-hidden
          />
        </div>
      </div>
    );
  }

  return (
    <div className={cn("flex flex-col gap-2", className)}>
      <div className="flex items-center gap-2">
        <span className={cn("rounded-md px-2 py-0.5 text-xs font-bold tracking-wide", tierColor)}>
          {level.name}
        </span>
        <span className="text-xs font-medium text-muted-foreground">Level {level.level}</span>
      </div>

      <div className="flex flex-col gap-1">
        <div className="progress-track h-2">
          <div
            className="progress-fill h-full transition-all duration-700 ease-out"
            style={{ width: `${pct}%` }}
            aria-label={`${Math.round(pct)}% progress to next level`}
          />
        </div>
        <div className="flex items-center justify-between">
          <span className="text-xs text-muted-foreground tabular-nums">{xpLabel}</span>
          {!isMaxLevel && (
            <span className="text-xs text-muted-foreground tabular-nums">
              {Math.round(pct)}%
            </span>
          )}
        </div>
      </div>
    </div>
  );
}
