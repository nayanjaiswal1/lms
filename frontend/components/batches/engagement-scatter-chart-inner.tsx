"use client";

import { CartesianGrid, Cell, ReferenceLine, ResponsiveContainer, Scatter, ScatterChart, Tooltip, XAxis, YAxis, ZAxis } from "recharts";
import type { EngagementPoint } from "@/lib/server/batches";

interface ChartTooltipProps {
  active?: boolean;
  payload?: { payload: EngagementPoint }[];
}

function ChartTooltip({ active, payload }: ChartTooltipProps) {
  if (!active || !payload?.length) return null;
  const p = payload[0].payload;
  return (
    <div className="card-base px-3 py-2 text-xs shadow-raised">
      <p className="font-medium text-foreground">{p.user_name}</p>
      <p className="text-muted-foreground">{p.days_active} days active · {p.problems_solved} solved</p>
    </div>
  );
}

function median(values: number[]): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
}

// Quadrant color follows the point's identity (Stars/Struggling/etc), split
// at the batch's own median activity and solve-count — no fixed thresholds.
function quadrantColor(point: EngagementPoint, daysMedian: number, solvedMedian: number): string {
  const highActivity = point.days_active >= daysMedian;
  const highProgress = point.problems_solved >= solvedMedian;
  if (highActivity && highProgress) return "hsl(var(--success))";
  if (!highActivity && highProgress) return "hsl(var(--ai))";
  if (highActivity && !highProgress) return "hsl(var(--warning))";
  return "hsl(var(--destructive))";
}

export default function EngagementScatterChartInner({ points }: { points: EngagementPoint[] }) {
  const daysMedian = median(points.map((p) => p.days_active));
  const solvedMedian = median(points.map((p) => p.problems_solved));

  return (
    <ResponsiveContainer height={320} width="100%">
      <ScatterChart margin={{ left: 8, right: 16, top: 8, bottom: 8 }}>
        <CartesianGrid stroke="hsl(var(--border))" />
        <XAxis
          dataKey="days_active"
          name="Days active"
          stroke="hsl(var(--muted-foreground))"
          tick={{ fontSize: 12 }}
          type="number"
        />
        <YAxis
          dataKey="problems_solved"
          name="Problems solved"
          stroke="hsl(var(--muted-foreground))"
          tick={{ fontSize: 12 }}
          type="number"
        />
        <ZAxis range={[80, 80]} />
        <ReferenceLine stroke="hsl(var(--border))" strokeDasharray="4 4" x={daysMedian} />
        <ReferenceLine stroke="hsl(var(--border))" strokeDasharray="4 4" y={solvedMedian} />
        <Tooltip content={<ChartTooltip />} cursor={{ strokeDasharray: "3 3" }} />
        <Scatter data={points}>
          {points.map((p) => (
            <Cell fill={quadrantColor(p, daysMedian, solvedMedian)} key={p.user_id} />
          ))}
        </Scatter>
      </ScatterChart>
    </ResponsiveContainer>
  );
}
