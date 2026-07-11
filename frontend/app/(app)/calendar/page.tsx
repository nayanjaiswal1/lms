import type { Metadata } from "next";
import { listEventsAction } from "@/lib/server/calendar";
import { getCurrentUser } from "@/lib/server/auth";
import { CalendarGrid } from "@/app/(app)/calendar/calendar-grid";
import { isoDateParam, rangeForView } from "@/app/(app)/calendar/calendar-math";
import { CALENDAR_VIEW } from "@/lib/calendar/types";
import type { CalendarView } from "@/lib/calendar/types";

export const metadata: Metadata = {
  title: "Calendar",
  description: "Time-blocking calendar for scheduling tasks, events, mentor sessions, and more.",
};

interface CalendarPageProps {
  searchParams: Promise<{ view?: string; date?: string }>;
}

const VALID_VIEWS = new Set<string>(Object.values(CALENDAR_VIEW));

export default async function CalendarPage({ searchParams }: CalendarPageProps) {
  const params = await searchParams;
  const view: CalendarView = VALID_VIEWS.has(params.view ?? "") ? (params.view as CalendarView) : CALENDAR_VIEW.MONTH;
  const anchor = params.date && !Number.isNaN(Date.parse(params.date)) ? new Date(params.date) : new Date();

  const { from, to } = rangeForView(view, anchor);
  const [eventsResult, currentUser] = await Promise.all([
    listEventsAction(isoDateParam(from), isoDateParam(to)),
    getCurrentUser(),
  ]);

  return (
    <main className="page-container py-8">
      <div className="mb-6 flex flex-col gap-1">
        <h1 className="page-title">Calendar</h1>
        <p className="text-muted-foreground">Time-block your tasks, schedule events, and manage your time effectively.</p>
      </div>
      <CalendarGrid
        currentUserId={currentUser?.id ?? ""}
        initialAnchor={anchor.toISOString()}
        initialError={eventsResult.error}
        initialEvents={eventsResult.data ?? []}
        initialView={view}
      />
    </main>
  );
}
