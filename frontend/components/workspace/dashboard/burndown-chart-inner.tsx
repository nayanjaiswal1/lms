"use client";

import { CartesianGrid, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import type { DayPoint } from "@/lib/workspace/types";

interface ChartTooltipProps {
  active?: boolean;
  payload?: { payload: DayPoint }[];
}

function ChartTooltip({ active, payload }: ChartTooltipProps) {
  if (!active || !payload?.length) return null;
  const p = payload[0].payload;
  return (
    <div className="card-base px-3 py-2 text-xs shadow-raised">
      <p className="font-medium text-foreground">{p.day}</p>
      <p className="text-muted-foreground">{p.open} open · {p.done} done today · {p.added} added today</p>
    </div>
  );
}

// A continuous daily trend (not discrete categories, unlike
// assignment-burndown-inner.tsx's grouped bars) — a line chart is the right
// mark shape here.
export default function BurndownChartInner({ burndown }: { burndown: DayPoint[] }) {
  return (
    <ResponsiveContainer height={240} width="100%">
      <LineChart data={burndown} margin={{ left: 0, right: 8, top: 4, bottom: 4 }}>
        <CartesianGrid stroke="hsl(var(--border))" vertical={false} />
        <XAxis dataKey="day" stroke="hsl(var(--muted-foreground))" tick={{ fontSize: 11 }} />
        <YAxis allowDecimals={false} stroke="hsl(var(--muted-foreground))" tick={{ fontSize: 12 }} />
        <Tooltip content={<ChartTooltip />} cursor={{ stroke: "hsl(var(--border))" }} />
        <Line dataKey="open" dot={false} name="Open" stroke="hsl(var(--primary))" strokeWidth={2} type="monotone" />
      </LineChart>
    </ResponsiveContainer>
  );
}
