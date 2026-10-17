import { Suspense } from "react";

import { Skeleton } from "@/components/ui/skeleton";
import ROUTES from "@/lib/routes";
import { DashboardSectionHeader } from "./section-header";
import {
  AIConnectorNudgeSection,
  CoursesSection,
  RandomTopicSection,
  ReviewSection,
  StandingSection,
  UpcomingSection,
} from "../sections";

interface LearnerDashboardProps {
  firstName: string;
  userId: string;
  scope?: string;
  scopeId?: string;
  /** Viewer persona: courses only, no practice/standing/review widgets. */
  coursesOnly?: boolean;
}

// Static shell (header, section titles, links) paints immediately; each data
// section streams in behind its own Suspense boundary.
export function LearnerDashboard({ firstName, userId, scope, scopeId, coursesOnly = false }: LearnerDashboardProps) {
  return (
    <main className="page-container">
      <div className="mb-8 flex flex-col gap-4 lg:flex-row lg:items-center lg:gap-6">
        <div className="flex flex-col gap-2">
          <h1>Welcome back, {firstName}</h1>
          <p className="text-muted-foreground">Here&apos;s your learning overview.</p>
        </div>
        {!coursesOnly && (
          <div className="lg:ml-auto">
            <Suspense fallback={null}>
              <AIConnectorNudgeSection />
            </Suspense>
          </div>
        )}
      </div>

      <div className="grid grid-cols-1 gap-8 lg:grid-cols-3">
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
          {!coursesOnly && (
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
          )}
        </div>

        {!coursesOnly && (
        <aside className="flex flex-col gap-8 lg:col-span-1">
          <Suspense fallback={<Skeleton className="h-40" />}>
            <RandomTopicSection />
          </Suspense>
          <Suspense fallback={<Skeleton className="h-32" />}>
            <ReviewSection />
          </Suspense>
          {/* Your standing — XP/achievements, batch, and leaderboard rank, one card.
              Batch used to be its own box; it's now a scope filter here instead,
              since "which leaderboard" and "which batch" are the same question. */}
          <Suspense fallback={<Skeleton className="h-72" />}>
            <StandingSection scope={scope} scopeId={scopeId} userId={userId} />
          </Suspense>
        </aside>
        )}
      </div>
    </main>
  );
}
