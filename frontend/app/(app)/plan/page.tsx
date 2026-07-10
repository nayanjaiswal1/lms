import type { Metadata } from "next";
import { getDayPlanAction, getPlanInboxAction } from "@/lib/server/whatnow";
import { PlanDayApp } from "@/components/whatnow/plan-day-app";
import { WhatNowSwitch } from "@/components/whatnow/whatnow-switch";
import { isoDateParam } from "@/lib/whatnow/day-math";

export const metadata: Metadata = {
  title: "Plan Day",
  description: "Rank what matters, then block time for it.",
};

interface PlanPageProps {
  searchParams: Promise<{ date?: string }>;
}

export default async function PlanPage({ searchParams }: PlanPageProps) {
  const params = await searchParams;
  const anchor = params.date && !Number.isNaN(Date.parse(params.date)) ? new Date(params.date) : new Date();
  const date = isoDateParam(anchor);

  const [planResult, inboxResult] = await Promise.all([
    getDayPlanAction(date),
    getPlanInboxAction(),
  ]);

  return (
    <div className="relative">
      <main className="page-container py-8">
        <div className="mb-6 flex flex-col gap-1">
          <h1 className="page-title">Plan Day</h1>
          <p className="text-muted-foreground">Rank what matters, then block time for it.</p>
        </div>
        <PlanDayApp
          initialDate={date}
          initialError={planResult.error}
          initialInbox={inboxResult.data ?? []}
          initialPlan={planResult.data ?? { date, scheduled: [], unscheduled: [] }}
        />
      </main>
      <WhatNowSwitch />
    </div>
  );
}
