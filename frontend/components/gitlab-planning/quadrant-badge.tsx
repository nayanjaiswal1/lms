import { CalendarDays, Clock, Trash2, Zap } from "lucide-react";
import type { AeMTone, AeQuadrantKey } from "@/lib/gitlab-planning/types";

const QUADRANT: Record<AeQuadrantKey, { label: string; icon: typeof Zap; tone: AeMTone | "error-strong" }> = {
  do_now: { label: "Do it Now", icon: Zap, tone: "error-strong" },
  plan: { label: "Plan / Delegate", icon: CalendarDays, tone: "secondary" },
  park: { label: "Park it", icon: Clock, tone: "secondary" },
  eliminate: { label: "Eliminate", icon: Trash2, tone: "muted" },
};

interface QuadrantBadgeProps {
  quadrant: AeQuadrantKey;
}

export function QuadrantBadge({ quadrant }: QuadrantBadgeProps) {
  const { label, icon: Icon, tone } = QUADRANT[quadrant];
  return (
    <span data-mtone={tone} className="m-label-sm inline-flex items-center gap-1 rounded-full bg-(--mc-bg) px-2 py-0.5 text-[11px] font-semibold text-(--mc-fg)">
      <Icon className="size-3" aria-hidden />
      <span>{label}</span>
    </span>
  );
}
