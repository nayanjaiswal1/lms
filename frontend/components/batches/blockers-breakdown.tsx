import { Info } from "lucide-react";
import type { BlockersBreakdown as BlockersBreakdownData } from "@/lib/server/batches";

interface BlockersBreakdownProps {
  data: BlockersBreakdownData;
}

const SEGMENT_CLASS = ["bg-primary", "bg-ai", "bg-warning"];

export function BlockersBreakdown({ data }: BlockersBreakdownProps) {
  const total = data.buckets.reduce((sum, b) => sum + b.count, 0);

  if (total === 0) {
    return (
      <div className="empty-state py-10">
        <p className="text-sm text-muted-foreground">No hint activity yet.</p>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex h-3 w-full overflow-hidden rounded-full bg-muted">
        {data.buckets.map((b, i) => {
          const pct = (b.count / total) * 100;
          if (pct === 0) return null;
          return (
            <div
              className={`${SEGMENT_CLASS[i % SEGMENT_CLASS.length]} h-full border-r-2 border-background last:border-r-0`}
              key={b.category}
              // eslint-disable-next-line no-restricted-syntax -- segment width is data-proportional, computed per render
              style={{ width: `${pct}%` }}
              title={`${b.category}: ${b.count}`}
            />
          );
        })}
      </div>
      <div className="flex flex-wrap gap-x-5 gap-y-1.5 text-sm">
        {data.buckets.map((b, i) => (
          <div className="flex items-center gap-1.5" key={b.category}>
            <span aria-hidden className={`inline-block h-2.5 w-2.5 rounded-sm ${SEGMENT_CLASS[i % SEGMENT_CLASS.length]}`} />
            <span className="text-foreground">{b.category}</span>
            <span className="text-muted-foreground">{b.count}</span>
          </div>
        ))}
      </div>
      {data.estimated && (
        <p className="flex items-start gap-1.5 text-xs text-muted-foreground">
          <Info aria-hidden className="h-3.5 w-3.5 flex-shrink-0 mt-0.5" />
          Estimated from hint-request escalation level, not a direct classification of the mistake.
        </p>
      )}
    </div>
  );
}
