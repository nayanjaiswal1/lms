"use client";

import { Bar, CartesianGrid, ComposedChart, Line, ResponsiveContainer, XAxis, YAxis } from "recharts";
import type { SleepPoint } from "@/lib/habits/summaries";

export default function SleepQualityChartInner({ points }: { points: SleepPoint[] }) {
  const today = points.at(-1)?.day;
  return (
    <ResponsiveContainer height={220} width="100%">
      <ComposedChart data={points} margin={{ left: 0, right: 8, top: 8, bottom: 0 }}>
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
          yAxisId="hours"
        />
        {/* Night-wake count on its own right-side axis — a separate scale
            (0-5 wakes) from sleep duration, plotted as light bars behind the
            hours line rather than crowding the same axis. */}
        <YAxis
          domain={[0, 5]}
          hide
          orientation="right"
          ticks={[0, 5]}
          yAxisId="wakes"
        />
        <Bar
          barSize={6}
          dataKey="wakes"
          fill="hsl(var(--muted-foreground) / 0.35)"
          isAnimationActive={false}
          yAxisId="wakes"
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
          yAxisId="hours"
        />
      </ComposedChart>
    </ResponsiveContainer>
  );
}
