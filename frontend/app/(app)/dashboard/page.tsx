import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { Suspense } from "react";

import { Skeleton } from "@/components/ui/skeleton";
import ROUTES from "@/lib/routes";
import { getCurrentUser } from "@/lib/server/auth";
import { DashboardSectionHeader } from "./_components/section-header";
import {
  AIConnectorNudgeSection,
  CoursesSection,
  ReviewSection,
  StandingSection,
  UpcomingSection,
} from "./sections";

export const metadata: Metadata = {
  title: "Dashboard",
  description: "Your MindForge learning dashboard.",
};

interface DashboardPageProps {
  searchParams: Promise<{ scope?: string; scope_id?: string }>;
}

// Static shell (header, section titles, links) paints immediately; each data
// section streams in behind its own Suspense boundary.
export default async function DashboardPage({ searchParams }: DashboardPageProps) {
  const [user, params] = await Promise.all([getCurrentUser(), searchParams]);
  if (!user) redirect(ROUTES.LOGIN);

  const firstName = user.name.trim().split(" ")[0] || user.email;

  return (
    <main className="page-container">
      <div className="mb-8 flex flex-col gap-2">
        <h1>Welcome back, {firstName}</h1>
        <p className="text-muted-foreground">Here&apos;s your learning overview.</p>
      </div>

      <Suspense fallback={null}>
        <AIConnectorNudgeSection />
      </Suspense>

      <div className="grid grid-cols-1 gap-8 lg:grid-cols-3">
        {/* Main column */}
        <div className="lg:col-span-2">
          <section className="mb-8">
            <DashboardSectionHeader
              link={{ href: ROUTES.COURSES, label: "View all" }}
              title="Your courses"
            />
            <Suspense
              fallback={
                <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
                  {Array.from({ length: 3 }).map((_, i) => (
                    <Skeleton className="h-48" key={i} />
                  ))}
                </div>
              }
            >
              <CoursesSection />
            </Suspense>
          </section>

          {/* Upcoming — assessments due and calendar events, merged into one timeline */}
          <section>
            <DashboardSectionHeader
              link={{ href: ROUTES.CALENDAR, label: "Calendar" }}
              title="Upcoming"
            />
            <Suspense
              fallback={
                <div className="flex flex-col gap-3">
                  {Array.from({ length: 3 }).map((_, i) => (
                    <Skeleton className="h-16" key={i} />
                  ))}
                </div>
              }
            >
              <UpcomingSection />
            </Suspense>
          </section>
        </div>

        {/* Right rail */}
        <aside className="flex flex-col gap-8 lg:col-span-1">
          <Suspense fallback={<Skeleton className="h-32" />}>
            <ReviewSection />
          </Suspense>
          {/* Your standing — XP/achievements, batch, and leaderboard rank, one card.
              Batch used to be its own box; it's now a scope filter here instead,
              since "which leaderboard" and "which batch" are the same question. */}
          <Suspense fallback={<Skeleton className="h-72" />}>
            <StandingSection scope={params.scope} scopeId={params.scope_id} userId={user.id} />
          </Suspense>
        </aside>
      </div>
    </main>
  );
}
