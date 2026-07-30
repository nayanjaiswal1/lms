import { ListChecks, ShieldCheck, Clock, type LucideIcon } from "lucide-react";

interface HeaderStatsProps {
  questionCount: number;
  totalPoints: number;
  durationMinutes: number;
}

const STATS: { key: string; icon: LucideIcon; label: string }[] = [
  { key: "questions", icon: ListChecks, label: "Questions" },
  { key: "points", icon: ShieldCheck, label: "Points" },
  { key: "duration", icon: Clock, label: "Duration" },
];

// Small stat-tile row for the assessment builder header, replacing the
// plain "9 questions · 73 points · 15 min" text line with the same tile
// look used for meta stats elsewhere (see proctor-preflight.tsx).
export function HeaderStats({ questionCount, totalPoints, durationMinutes }: HeaderStatsProps) {
  const values: Record<string, string> = {
    questions: `${questionCount}`,
    points: `${totalPoints}`,
    duration: `${durationMinutes}m`,
  };

  return (
    <div className="flex flex-wrap items-center gap-2">
      {STATS.map(({ key, icon: Icon, label }) => (
        <div className="flex items-center gap-1.5 rounded-md border border-border/60 bg-card px-2.5 py-1" key={key}>
          <Icon aria-hidden className="h-3.5 w-3.5 text-muted-foreground" />
          <span className="text-sm font-semibold tabular-nums">{values[key]}</span>
          <span className="text-xs text-muted-foreground">{label}</span>
        </div>
      ))}
    </div>
  );
}
