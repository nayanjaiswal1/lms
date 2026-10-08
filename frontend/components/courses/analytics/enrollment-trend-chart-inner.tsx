"use client";

import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import type { EnrollmentPoint } from "@/lib/server/course-analytics";

interface ChartTooltipProps {
  active?: boolean;
  payload?: { payload: EnrollmentPoint }[];
}

function ChartTooltip({ active, payload }: ChartTooltipProps) {
  if (!active || !payload?.length) return null;
  const p = payload[0].payload;
  return (
    <div className="card-base px-3 py-2 text-xs shadow-raised">
      <p className="font-medium text-foreground">{new Date(p.date).toLocaleDateString()}</p>
      <p className="text-muted-foreground">{p.enrollments} enrollments</p>
    </div>
  );
}

export default function EnrollmentTrendChartInner({ points }: { points: EnrollmentPoint[] }) {
  return (
    <ResponsiveContainer height={208} width="100%">
      <BarChart data={points} margin={{ left: 0, right: 8, top: 4, bottom: 4 }}>
        <CartesianGrid stroke="hsl(var(--border))" vertical={false} />
        <XAxis
          dataKey="date"
          minTickGap={24}
          stroke="hsl(var(--muted-foreground))"
          tick={{ fontSize: 12 }}
          tickFormatter={(d: string) => new Date(d).toLocaleDateString(undefined, { month: "short", day: "numeric" })}
        />
        <YAxis allowDecimals={false} stroke="hsl(var(--muted-foreground))" tick={{ fontSize: 12 }} width={32} />
        <Tooltip content={<ChartTooltip />} cursor={{ fill: "hsl(var(--muted))" }} />
        <Bar dataKey="enrollments" fill="hsl(var(--primary))" radius={[4, 4, 0, 0]} />
      </BarChart>
    </ResponsiveContainer>
  );
}
