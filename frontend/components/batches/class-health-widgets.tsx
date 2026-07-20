import { Users, TrendingUp, AlertTriangle, TrendingDown } from "lucide-react";
import type { ClassHealth } from "@/lib/server/batches";
import type { Terminology } from "@/lib/terminology";

interface ClassHealthWidgetsProps {
  health: ClassHealth;
  t: Terminology;
}

export function ClassHealthWidgets({ health, t }: ClassHealthWidgetsProps) {
  return (
    <div className="grid-stats">
      <div className="card-base flex flex-col gap-1 p-5">
        <div className="flex items-center gap-2 text-sm text-muted-foreground">
          <Users aria-hidden className="h-4 w-4" />
          Total {t.studentPlural.toLowerCase()}
        </div>
        <p className="text-2xl font-bold">{health.total_students}</p>
      </div>
      <div className="card-base flex flex-col gap-1 p-5">
        <div className="flex items-center gap-2 text-sm text-muted-foreground">
          <TrendingUp aria-hidden className="h-4 w-4" />
          On track
        </div>
        <p className="text-2xl font-bold text-success">{health.on_track_pct}%</p>
      </div>
      <div className="card-base flex flex-col gap-1 p-5">
        <div className="flex items-center gap-2 text-sm text-muted-foreground">
          <AlertTriangle aria-hidden className="h-4 w-4" />
          Needs support
        </div>
        <p className="text-2xl font-bold text-warning">{health.needs_support_pct}%</p>
      </div>
      <div className="card-base flex flex-col gap-1 p-5">
        <div className="flex items-center gap-2 text-sm text-muted-foreground">
          <TrendingDown aria-hidden className="h-4 w-4" />
          Not engaged
        </div>
        <p className="text-2xl font-bold text-destructive">{health.not_engaged_pct}%</p>
      </div>
    </div>
  );
}
