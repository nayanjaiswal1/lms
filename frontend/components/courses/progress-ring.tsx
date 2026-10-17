"use client";

import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";

interface ProgressRingProps {
  pct: number;
  completed?: number;
  total?: number;
}

// Donut with the exact percent inside; hover/focus shows modules done. Sits
// above the card's full-area link overlay (relative z-raised) so it can be hovered.
export function ProgressRing({ pct, completed, total }: ProgressRingProps) {
  const value = Math.min(Math.max(Math.round(pct), 0), 100);
  const r = 15;
  const c = 2 * Math.PI * r;
  const detail =
    completed !== undefined && total !== undefined
      ? `${completed} of ${total} lesson${total === 1 ? "" : "s"} completed`
      : `${value}% complete`;

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <svg
          aria-label={detail}
          className="relative z-raised ml-auto h-9 w-9 shrink-0 text-primary"
          role="img"
          tabIndex={0}
          viewBox="0 0 36 36"
        >
          <g className="origin-center -rotate-90">
            <circle className="stroke-muted" cx="18" cy="18" fill="none" r={r} strokeWidth="3" />
            <circle
              cx="18"
              cy="18"
              fill="none"
              r={r}
              stroke="currentColor"
              strokeDasharray={c}
              strokeDashoffset={c * (1 - value / 100)}
              strokeLinecap="round"
              strokeWidth="3"
            />
          </g>
          <text className="fill-foreground text-[9px] font-semibold" dominantBaseline="central" textAnchor="middle" x="18" y="18">
            {value}%
          </text>
        </svg>
      </TooltipTrigger>
      <TooltipContent>{detail}</TooltipContent>
    </Tooltip>
  );
}
