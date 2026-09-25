import { CalendarDays, Clock, Trash2, Zap } from "lucide-react";
import type { AeMTone, AeQuadrantKey } from "@/lib/server/gitlab-planning";

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
    <span className="m-label-sm inline-flex items-center gap-1 rounded-full bg-(--mc-bg) px-2 py-0.5 text-xs font-semibold text-(--mc-fg)" data-mtone={tone}>
      <Icon aria-hidden className="size-3" />
      <span>{label}</span>
    </span>
  );
}
