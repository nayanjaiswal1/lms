import { BurndownChart } from "@/components/workspace/dashboard/burndown-chart";
import type { Delivery } from "@/lib/workspace/types";

function formatHours(stat: { count: number; median_hours: number | null }): string {
  if (stat.count === 0 || stat.median_hours === null) return "—";
  const days = stat.median_hours / 24;
  return days >= 1 ? `${days.toFixed(1)}d` : `${stat.median_hours.toFixed(0)}h`;
}

interface DeliverySectionProps {
  delivery: Delivery;
}

export function DeliverySection({ delivery }: DeliverySectionProps) {
  return (
    <div className="card-base flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <h2 className="section-title">Delivery</h2>
        <span className="text-sm text-muted-foreground">{delivery.progress_pct.toFixed(0)}% complete</span>
      </div>
      <div className="progress-track">
        {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width requires inline style */}
        <div className="progress-fill" style={{ width: `${Math.min(100, delivery.progress_pct)}%` }} />
      </div>

      <div className="grid-stats">
        <div>
          <p className="text-xs text-muted-foreground">Remaining</p>
          <p className="text-lg font-semibold">{delivery.forecast.remaining}</p>
        </div>
        <div>
          <p className="text-xs text-muted-foreground">Weekly throughput</p>
          <p className="text-lg font-semibold">{delivery.forecast.weekly_throughput.toFixed(1)}</p>
        </div>
        <div>
          <p className="text-xs text-muted-foreground">Lead time (median)</p>
          <p className="text-lg font-semibold">{formatHours(delivery.lead_time)}</p>
        </div>
        <div>
          <p className="text-xs text-muted-foreground">Blocked hours</p>
          <p className="text-lg font-semibold">{delivery.blocked_hours.toFixed(0)}h</p>
        </div>
      </div>

      {delivery.forecast.projected_finish && (
        <p className="text-xs text-muted-foreground">
          Projected finish: {new Date(delivery.forecast.projected_finish).toLocaleDateString()}
        </p>
      )}

      <BurndownChart burndown={delivery.burndown} />
    </div>
  );
}
