"use client";

import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import type { ChapterHintStat } from "@/lib/server/batches";

interface ChartTooltipProps {
  active?: boolean;
  payload?: { payload: ChapterHintStat }[];
}

function ChartTooltip({ active, payload }: ChartTooltipProps) {
  if (!active || !payload?.length) return null;
  const stat = payload[0].payload;
  return (
    <div className="card-base px-3 py-2 text-xs shadow-raised">
      <p className="font-medium text-foreground">{stat.section_title}</p>
      <p className="text-muted-foreground">{stat.avg_hints.toFixed(1)} avg hints · {stat.student_count} students</p>
    </div>
  );
}

export default function ChapterHintBarChartInner({ stats }: { stats: ChapterHintStat[] }) {
  const height = Math.max(160, stats.length * 36);
  return (
    <ResponsiveContainer height={height} width="100%">
      <BarChart data={stats} layout="vertical" margin={{ left: 8, right: 16, top: 4, bottom: 4 }}>
        <CartesianGrid horizontal={false} stroke="hsl(var(--border))" />
        <XAxis stroke="hsl(var(--muted-foreground))" tick={{ fontSize: 12 }} type="number" />
        <YAxis
          dataKey="section_title"
          stroke="hsl(var(--muted-foreground))"
          tick={{ fontSize: 12 }}
          type="category"
          width={110}
        />
        <Tooltip content={<ChartTooltip />} cursor={{ fill: "hsl(var(--muted))" }} />
        <Bar dataKey="avg_hints" fill="hsl(var(--primary))" radius={[0, 4, 4, 0]} />
      </BarChart>
    </ResponsiveContainer>
  );
}
