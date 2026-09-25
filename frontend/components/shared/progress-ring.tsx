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
      aria-label={`${pct}% complete`}
      className="-rotate-90 shrink-0"
      height={size}
      role="img"
      viewBox={`0 0 ${size} ${size}`}
      width={size}
    >
      <circle className="stroke-muted" cx={size / 2} cy={size / 2} fill="none" r={radius} strokeWidth={STROKE_WIDTH} />
      <circle
        className={cn("stroke-primary transition-all duration-slow ease-smooth", className)}
        cx={size / 2}
        cy={size / 2}
        fill="none"
        r={radius}
        strokeDasharray={circumference}
        strokeDashoffset={offset}
        strokeLinecap="round"
        strokeWidth={STROKE_WIDTH}
      />
    </svg>
  );
}
