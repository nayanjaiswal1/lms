"use client";

import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { MISTAKE_CATEGORY_OPTIONS, MISTAKE_TREND_LABEL } from "@/lib/constants";
import type { CategorySummary } from "@/lib/server/mistakes";

const CATEGORY_LABEL: Record<string, string> = Object.fromEntries(
  MISTAKE_CATEGORY_OPTIONS.map((o) => [o.value, o.label]),
);

interface ChartRow {
  category: string;
  label: string;
  total: number;
  trend: CategorySummary["trend"];
}

interface ChartTooltipProps {
  active?: boolean;
  payload?: { payload: ChartRow }[];
}

function ChartTooltip({ active, payload }: ChartTooltipProps) {
  if (!active || !payload?.length) return null;
  const row = payload[0].payload;
  return (
    <div className="card-base px-3 py-2 text-xs shadow-raised">
      <p className="font-medium text-foreground">{row.label}</p>
      <p className="text-muted-foreground">
        {row.total} mistake{row.total !== 1 ? "s" : ""} · {MISTAKE_TREND_LABEL[row.trend]}
      </p>
    </div>
  );
}

export default function MistakeTrendChartInner({ summary }: { summary: CategorySummary[] }) {
  const data: ChartRow[] = summary.map((s) => ({
    category: s.category,
    label: CATEGORY_LABEL[s.category] ?? s.category,
    total: s.total,
    trend: s.trend,
  }));
  const height = Math.max(160, data.length * 36);

  return (
    <ResponsiveContainer height={height} width="100%">
      <BarChart data={data} layout="vertical" margin={{ left: 8, right: 16, top: 4, bottom: 4 }}>
        <CartesianGrid horizontal={false} stroke="hsl(var(--border))" />
        <XAxis allowDecimals={false} stroke="hsl(var(--muted-foreground))" tick={{ fontSize: 12 }} type="number" />
        <YAxis
          dataKey="label"
          stroke="hsl(var(--muted-foreground))"
          tick={{ fontSize: 12 }}
          type="category"
          width={140}
        />
        <Tooltip content={<ChartTooltip />} cursor={{ fill: "hsl(var(--muted))" }} />
        <Bar dataKey="total" fill="hsl(var(--primary))" radius={[0, 4, 4, 0]} />
      </BarChart>
    </ResponsiveContainer>
  );
}
