"use client";

import { CartesianGrid, Line, LineChart, ResponsiveContainer, XAxis, YAxis } from "recharts";
import type { SleepPoint } from "@/lib/habits/summaries";

export default function SleepQualityChartInner({ points }: { points: SleepPoint[] }) {
  const today = points.at(-1)?.day;
  return (
    <ResponsiveContainer height={220} width="100%">
      <LineChart data={points} margin={{ left: 0, right: 8, top: 8, bottom: 0 }}>
        <CartesianGrid stroke="hsl(var(--border))" strokeDasharray="4 4" vertical={false} />
        <XAxis
          dataKey="day"
          stroke="hsl(var(--muted-foreground))"
          tick={{ fontSize: 10 }}
          tickLine={false}
          type="number"
          domain={[1, "dataMax"]}
        />
        <YAxis
          domain={[4, 10]}
          stroke="hsl(var(--muted-foreground))"
          tick={{ fontSize: 10 }}
          tickFormatter={(v: number) => `${v}h`}
          tickLine={false}
          ticks={[4, 6, 8, 10]}
          width={28}
        />
        <Line
          connectNulls
          dataKey="hours"
          dot={(props: { cx?: number; cy?: number; payload: SleepPoint }) => (
            <circle
              cx={props.cx ?? 0}
              cy={props.cy ?? 0}
              fill={props.payload.day === today ? "hsl(var(--primary))" : "hsl(var(--foreground))"}
              key={props.payload.day}
              r={props.payload.day === today ? 3.5 : 2.5}
            />
          )}
          isAnimationActive={false}
          stroke="hsl(var(--foreground))"
          strokeDasharray="4 4"
          strokeWidth={1.5}
          type="linear"
        />
      </LineChart>
    </ResponsiveContainer>
  );
}
