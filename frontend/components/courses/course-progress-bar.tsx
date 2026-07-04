import { cn } from "@/lib/utils";

interface CourseProgressBarProps {
  completed: number;
  total: number;
  className?: string;
}

export function CourseProgressBar({ completed, total, className }: CourseProgressBarProps) {
  const pct = total > 0 ? Math.round((completed / total) * 100) : 0;

  return (
    <div className={cn("flex flex-col gap-2", className)}>
      <div className="flex items-baseline justify-between">
        <span className="text-lg font-bold tracking-tight text-primary">{pct}%</span>
        <span className="text-xs text-muted-foreground">{completed}/{total} complete</span>
      </div>
      <div className="progress-track border border-sidebar-border">
        {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width needs inline style */}
        <div className="progress-fill" style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
}
