import { cn } from "@/lib/utils";

interface ProgressRingProps {
  pct: number;
  size?: number;
  className?: string;
}

const STROKE_WIDTH = 3;

export function ProgressRing({ pct, size = 22, className }: ProgressRingProps) {
  const radius = (size - STROKE_WIDTH) / 2;
  const circumference = 2 * Math.PI * radius;
  const offset = circumference * (1 - Math.min(100, Math.max(0, pct)) / 100);

  return (
    <svg
      width={size}
      height={size}
      viewBox={`0 0 ${size} ${size}`}
      className="-rotate-90 shrink-0"
      role="img"
      aria-label={`${pct}% complete`}
    >
      <circle cx={size / 2} cy={size / 2} r={radius} fill="none" strokeWidth={STROKE_WIDTH} className="stroke-muted" />
      <circle
        cx={size / 2}
        cy={size / 2}
        r={radius}
        fill="none"
        strokeWidth={STROKE_WIDTH}
        strokeLinecap="round"
        strokeDasharray={circumference}
        strokeDashoffset={offset}
        className={cn("stroke-primary transition-all duration-slow ease-smooth", className)}
      />
    </svg>
  );
}
