import Link from "next/link";
import { CalendarClock, History, Wallet } from "lucide-react";

import { getBookingConfig, listSessions } from "@/lib/server/sessions";
import { SessionCard } from "@/components/sessions/session-card";
import ROUTES from "@/lib/routes";

interface SessionsSectionProps {
  currentUserId: string;
}

// Upcoming + past mentor sessions. Rendered on /calendar (the old standalone
// /sessions page now redirects there) — callers gate on SESSION_BOOKING.
export async function SessionsSection({ currentUserId }: SessionsSectionProps) {
  const [{ config, balance }, upcoming, past] = await Promise.all([
    getBookingConfig(),
    listSessions("upcoming"),
    listSessions("past"),
  ]);

  return (
    <section className="mt-10 flex flex-col gap-8" id="sessions">
      <div className="page-header">
        <div>
          <h2 className="page-title">My Sessions</h2>
          <p className="text-sm text-muted-foreground">Upcoming and past mentor sessions.</p>
        </div>
        {config.require_credits && (
          <Link
            className="flex items-center gap-1.5 rounded-md border border-border bg-card px-3 py-1.5 text-sm font-medium text-foreground transition-colors hover:bg-accent"
            href={ROUTES.SESSION_CREDITS}
          >
            <Wallet aria-hidden className="h-4 w-4 text-primary" />
            {balance} credit{balance === 1 ? "" : "s"}
          </Link>
        )}
      </div>

      <div className="flex flex-col gap-4">
        <h3 className="section-title">Upcoming</h3>
        {upcoming.length === 0 ? (
          <div className="empty-state">
            <CalendarClock aria-hidden className="empty-state-icon" />
            <p className="font-medium text-muted-foreground">No upcoming sessions.</p>
          </div>
        ) : (
          <div className="card-grid">
            {upcoming.map((session) => (
              <SessionCard key={session.id} session={session} viewerIsMentor={session.mentor_id === currentUserId} />
            ))}
          </div>
        )}
      </div>

      <div className="flex flex-col gap-4">
        <h3 className="section-title">Past</h3>
        {past.length === 0 ? (
          <div className="empty-state">
            <History aria-hidden className="empty-state-icon" />
            <p className="font-medium text-muted-foreground">No past sessions yet.</p>
          </div>
        ) : (
          <div className="card-grid">
            {past.map((session) => (
              <SessionCard key={session.id} session={session} viewerIsMentor={session.mentor_id === currentUserId} />
            ))}
          </div>
        )}
      </div>
    </section>
  );
}
