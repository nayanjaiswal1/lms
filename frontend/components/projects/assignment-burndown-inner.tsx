"use client";

import { Bar, BarChart, CartesianGrid, Legend, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import type { BurndownCheckpoint } from "@/lib/projects/types";

interface ChartTooltipProps {
  active?: boolean;
  payload?: { payload: BurndownCheckpoint }[];
}

function ChartTooltip({ active, payload }: ChartTooltipProps) {
  if (!active || !payload?.length) return null;
  const cp = payload[0].payload;
  return (
    <div className="card-base px-3 py-2 text-xs shadow-raised">
      <p className="font-medium text-foreground">{cp.title}</p>
      <p className="text-muted-foreground">
        {cp.closed_issues} closed · {cp.open_issues} open · {cp.total_issues} total
      </p>
    </div>
  );
}

// Two series (open vs closed) per checkpoint — a status pair, not a
// categorical set, so this reads off the semantic success/warning tokens
// rather than a generic categorical ramp. Grouped bars (not a trend line):
// checkpoints are discrete milestones here, not a continuous time axis, so a
// line would imply a trend the data doesn't actually carry.
export default function AssignmentBurndownInner({ checkpoints }: { checkpoints: BurndownCheckpoint[] }) {
  return (
    <div className="flex flex-col gap-2">
      <ResponsiveContainer height={260} width="100%">
        <BarChart data={checkpoints} margin={{ left: 0, right: 8, top: 4, bottom: 4 }}>
          <CartesianGrid stroke="hsl(var(--border))" vertical={false} />
          <XAxis dataKey="title" stroke="hsl(var(--muted-foreground))" tick={{ fontSize: 12 }} />
          <YAxis allowDecimals={false} stroke="hsl(var(--muted-foreground))" tick={{ fontSize: 12 }} />
          <Tooltip content={<ChartTooltip />} cursor={{ fill: "hsl(var(--muted))" }} />
          <Legend wrapperStyle={{ fontSize: 12 }} />
          <Bar dataKey="closed_issues" fill="hsl(var(--success))" name="Closed" radius={[4, 4, 0, 0]} stackId="issues" />
          <Bar dataKey="open_issues" fill="hsl(var(--warning))" name="Open" radius={[4, 4, 0, 0]} stackId="issues" />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
