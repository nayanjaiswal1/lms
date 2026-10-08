"use client";

import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import type { FunnelCounts } from "@/lib/server/course-analytics";

interface Stage {
  stage: string;
  students: number;
}

interface ChartTooltipProps {
  active?: boolean;
  payload?: { payload: Stage }[];
}

function ChartTooltip({ active, payload }: ChartTooltipProps) {
  if (!active || !payload?.length) return null;
  const s = payload[0].payload;
  return (
    <div className="card-base px-3 py-2 text-xs shadow-raised">
      <p className="font-medium text-foreground">{s.stage}</p>
      <p className="text-muted-foreground">{s.students} students</p>
    </div>
  );
}

export default function FunnelChartInner({ funnel }: { funnel: FunnelCounts }) {
  const data: Stage[] = [
    { stage: "Enrolled", students: funnel.enrolled },
    { stage: "Started", students: funnel.started },
    { stage: "25%", students: funnel.reached_25 },
    { stage: "50%", students: funnel.reached_50 },
    { stage: "75%", students: funnel.reached_75 },
    { stage: "Completed", students: funnel.completed },
  ];
  return (
    <ResponsiveContainer height={Math.max(200, data.length * 36)} width="100%">
      <BarChart data={data} layout="vertical" margin={{ left: 8, right: 16, top: 4, bottom: 4 }}>
        <CartesianGrid horizontal={false} stroke="hsl(var(--border))" />
        <XAxis allowDecimals={false} stroke="hsl(var(--muted-foreground))" tick={{ fontSize: 12 }} type="number" />
        <YAxis dataKey="stage" stroke="hsl(var(--muted-foreground))" tick={{ fontSize: 12 }} type="category" width={80} />
        <Tooltip content={<ChartTooltip />} cursor={{ fill: "hsl(var(--muted))" }} />
        <Bar dataKey="students" fill="hsl(var(--primary))" radius={[0, 4, 4, 0]} />
      </BarChart>
    </ResponsiveContainer>
  );
}
