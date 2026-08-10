import { cn } from "@/lib/utils";

interface CourseProgressBarProps {
  completed: number;
  total: number;
  className?: string;
}

const RADIUS = 15;
const CIRCUMFERENCE = 2 * Math.PI * RADIUS;

export function CourseProgressBar({ completed, total, className }: CourseProgressBarProps) {
  const pct = total > 0 ? Math.round((completed / total) * 100) : 0;
  const offset = CIRCUMFERENCE - (pct / 100) * CIRCUMFERENCE;

  return (
    <div className={cn("flex flex-col gap-2", className)}>
      <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Course progress</p>
      <div className="flex items-center gap-3">
        <div className="relative flex h-14 w-14 shrink-0 items-center justify-center">
          {/* -rotate-90 only on the circles (no text inside) so the arc starts
              at 12 o'clock instead of SVG's default 3 o'clock, without having
              to counter-rotate a nested <text> element back upright. */}
          <svg aria-hidden className="h-14 w-14 -rotate-90" viewBox="0 0 36 36">
            <circle
              className="text-muted-foreground/20"
              cx="18"
              cy="18"
              fill="none"
              r={RADIUS}
              stroke="currentColor"
              strokeWidth="3"
            />
            <circle
              className="text-primary"
              cx="18"
              cy="18"
              fill="none"
              r={RADIUS}
              stroke="currentColor"
              strokeDasharray={CIRCUMFERENCE}
              strokeLinecap="round"
              strokeWidth="3"
              // eslint-disable-next-line no-restricted-syntax -- dynamic progress offset needs inline style, same pattern as the old linear bar's width
              style={{ strokeDashoffset: offset, transition: "stroke-dashoffset var(--duration-slow) var(--ease-smooth)" }}
            />
          </svg>
          <span className="absolute text-xs font-bold tracking-tight text-primary">{pct}%</span>
        </div>
        <span className="text-sm font-semibold text-foreground">{completed} of {total} modules complete</span>
      </div>
    </div>
  );
}
