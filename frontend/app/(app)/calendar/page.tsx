import { requireAnyPermission } from "@/lib/server/permissions";
import { ACCESS } from "@/lib/auth/permission-codes";
import type { Metadata } from "next";
import { listEventsAction } from "@/lib/server/calendar";
import { getCurrentUser } from "@/lib/server/auth";
import { CalendarGrid } from "@/app/(app)/calendar/calendar-grid";
import { isoDateParam, rangeForView } from "@/app/(app)/calendar/calendar-math";
import { CALENDAR_VIEW } from "@/lib/calendar/types";
import { getFeatureConfig } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";
import { SessionsSection } from "@/components/sessions/sessions-section";
import type { CalendarView } from "@/lib/calendar/types";
import { cn } from "@/lib/utils";
import Link from "next/link";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Calendar",
  description: "Time-blocking calendar for scheduling tasks, events, mentor sessions, and more.",
};

interface CalendarPageProps {
  searchParams: Promise<{ view?: string; date?: string; tab?: string }>;
}

const CALENDAR_TAB = "calendar";
const SESSIONS_TAB = "sessions";
const VALID_VIEWS = new Set<string>(Object.values(CALENDAR_VIEW));

// Outside the component so the render stays pure (react-hooks/purity).
function parseAnchor(date?: string): Date {
  return date && !Number.isNaN(Date.parse(date)) ? new Date(date) : new Date();
}

export default async function CalendarPage({ searchParams }: CalendarPageProps) {
  await requireAnyPermission(ACCESS.CALENDAR);
  const params = await searchParams;
  const view: CalendarView = VALID_VIEWS.has(params.view ?? "") ? (params.view as CalendarView) : CALENDAR_VIEW.MONTH;
  const anchor = parseAnchor(params.date);

  const { from, to } = rangeForView(view, anchor);
  const [eventsResult, currentUser, features] = await Promise.all([
    listEventsAction(isoDateParam(from), isoDateParam(to)),
    getCurrentUser(),
    getFeatureConfig(),
  ]);
  const showSessions =
    features.orgFeatures.includes(FEATURES.SESSION_BOOKING) &&
    features.entitlements.includes(FEATURES.SESSION_BOOKING);

  const activeTab = showSessions && params.tab === SESSIONS_TAB ? SESSIONS_TAB : CALENDAR_TAB;
  const tabs = [
    { key: CALENDAR_TAB, label: "Calendar", href: ROUTES.CALENDAR },
    { key: SESSIONS_TAB, label: "My sessions", href: `${ROUTES.CALENDAR}?tab=${SESSIONS_TAB}` },
  ];

  return (
    <main className="page-container">
      <div className="mb-6 flex flex-col gap-1">
        <h1 className="page-title">Calendar</h1>
        <p className="hidden text-muted-foreground sm:block">Time-block your tasks, schedule events, and manage your time effectively.</p>
      </div>
      {showSessions && (
        <nav aria-label="Calendar sections" className="mb-4 flex rounded-lg bg-muted p-1 sm:inline-flex">
          {tabs.map((tab) => (
            <Link
              aria-current={tab.key === activeTab ? "page" : undefined}
              className={cn(
                "touch-target-dense flex flex-1 items-center justify-center rounded-md px-4 text-sm font-medium transition-colors duration-fast ease-smooth lg:h-8",
                tab.key === activeTab ? "bg-background text-foreground shadow-raised" : "text-muted-foreground hover:text-foreground",
              )}
              href={tab.href}
              key={tab.key}
            >
              {tab.label}
            </Link>
          ))}
        </nav>
      )}
      {activeTab === SESSIONS_TAB ? (
        <SessionsSection currentUserId={currentUser?.id ?? ""} />
      ) : (
        <CalendarGrid
          currentUserId={currentUser?.id ?? ""}
          initialAnchor={anchor.toISOString()}
          initialError={eventsResult.error}
          initialEvents={eventsResult.data ?? []}
          initialView={view}
        />
      )}
    </main>
  );
}
