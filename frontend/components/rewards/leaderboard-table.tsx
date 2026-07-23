"use client";

import { cn } from "@/lib/utils";
import type { LeaderboardEntry, UserAchievement } from "@/lib/server/rewards";

interface LeaderboardTableProps {
  entries: LeaderboardEntry[];
  myUserID?: string;
  myRank?: number;
  /** Progress (0-100) toward the next level — shown inline under your own row instead of a separate widget. */
  myProgressPct?: number;
  /** Shown inline under your own row instead of a separate widget. */
  myAchievements?: UserAchievement[];
}

const RANK_STYLES: Record<number, { ring: string; badge: string; text: string }> = {
  1: { ring: "ring-yellow-400/60", badge: "bg-yellow-400/10 text-yellow-600 dark:text-yellow-400", text: "🥇" },
  2: { ring: "ring-slate-300/60",  badge: "bg-slate-200/40 text-slate-500 dark:text-slate-300",   text: "🥈" },
  3: { ring: "ring-amber-600/50",  badge: "bg-amber-100/30 text-amber-700 dark:text-amber-400",   text: "🥉" },
};

function Avatar({ name, avatarUrl, isMe }: { name: string; avatarUrl?: string; isMe: boolean }) {
  const initials = name
    .split(" ")
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase() ?? "")
    .join("");

  return (
    <span
      className={cn(
        "flex h-8 w-8 shrink-0 items-center justify-center overflow-hidden rounded-full text-xs font-semibold ring-2 ring-offset-1",
        isMe ? "ring-primary" : "ring-border",
      )}
    >
      {avatarUrl ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img alt={name} className="h-full w-full object-cover" src={avatarUrl} />
      ) : (
        <span className={cn("flex h-full w-full items-center justify-center", isMe ? "bg-primary/10 text-primary" : "bg-muted text-muted-foreground")}>
          {initials || "?"}
        </span>
      )}
    </span>
  );
}

function RankCell({ rank }: { rank: number }) {
  const style = RANK_STYLES[rank];
  if (style) {
    return (
      <span className={cn("inline-flex h-7 w-7 items-center justify-center rounded-full text-sm", style.badge)}>
        {style.text}
      </span>
    );
  }
  return (
    <span className="w-7 text-center text-sm font-semibold tabular-nums text-muted-foreground">
      {rank}
    </span>
  );
}

export function MyRewardSummary({ progressPct, achievements }: { progressPct?: number; achievements?: UserAchievement[] }) {
  if (progressPct === undefined && !achievements?.length) return null;

  return (
    <div className="flex flex-col gap-2 pt-1">
      {progressPct !== undefined && (
        <div className="progress-track h-1.5">
          { }
          <div
            aria-label={`${Math.round(progressPct)}% progress to next level`}
            className="progress-fill h-full transition-all duration-700 ease-out"
            style={{ "--progress": `${Math.min(100, Math.max(0, progressPct))}%` } as React.CSSProperties}
          />
        </div>
      )}
      {achievements && achievements.length > 0 && (
        <div className="flex flex-wrap gap-1.5">
          {achievements.slice(0, 5).map((a) => (
            <span
              className="rounded-full border border-border bg-muted px-2 py-0.5 text-xs"
              key={a.id}
              title={a.definition.description}
            >
              {a.definition.icon} {a.definition.name}
            </span>
          ))}
          {achievements.length > 5 && (
            <span className="rounded-full border border-border bg-muted px-2 py-0.5 text-xs text-muted-foreground">
              +{achievements.length - 5} more
            </span>
          )}
        </div>
      )}
    </div>
  );
}

export function LeaderboardTable({ entries, myUserID, myRank, myProgressPct, myAchievements }: LeaderboardTableProps) {
  if (entries.length === 0) {
    return (
      <div className="empty-state py-12">
        <p className="text-sm text-muted-foreground">No entries yet. Be the first!</p>
      </div>
    );
  }

  const meInEntries = entries.some((e) => e.user_id === myUserID);

  return (
    <div className="flex flex-col gap-0 divide-y divide-border overflow-hidden rounded-xl border border-border">
      {entries.map((entry) => {
        const isMe = entry.user_id === myUserID;
        return (
          <div
            className={cn(
              "flex flex-col gap-2 px-4 py-3 transition-colors",
              isMe
                ? "bg-primary/10"
                : "bg-card hover:bg-muted/50",
            )}
            key={entry.user_id}
          >
            <div className="flex items-center gap-3">
              <div className="flex w-8 shrink-0 items-center justify-center">
                <RankCell rank={entry.rank} />
              </div>

              <Avatar avatarUrl={entry.avatar_url} isMe={isMe} name={entry.name} />

              <div className="min-w-0 flex-1">
                <p className={cn("truncate text-sm font-medium", isMe && "text-primary")}>
                  {entry.name}
                  {isMe && <span className="ml-1.5 text-xs font-normal text-muted-foreground">(you)</span>}
                </p>
                <p className="text-xs text-muted-foreground">{entry.level_name} · Lv.{entry.level}</p>
              </div>

              <div className="text-right">
                <p className="text-sm font-semibold tabular-nums">{entry.total_xp.toLocaleString()}</p>
                <p className="text-xs text-muted-foreground">XP</p>
              </div>
            </div>

            {isMe && <MyRewardSummary achievements={myAchievements} progressPct={myProgressPct} />}
          </div>
        );
      })}

      {myRank !== undefined && myUserID && !meInEntries && (
        <div className="flex flex-col gap-2 border-t-2 border-primary/30 bg-primary/10 px-4 py-3">
          <div className="flex items-center gap-3">
            <div className="flex w-8 shrink-0 items-center justify-center">
              <span className="w-7 text-center text-sm font-semibold tabular-nums text-muted-foreground">
                {myRank}
              </span>
            </div>
            <span className="text-xs text-muted-foreground italic">Your position</span>
          </div>
          <MyRewardSummary achievements={myAchievements} progressPct={myProgressPct} />
        </div>
      )}
    </div>
  );
}
