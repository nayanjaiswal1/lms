import type { Metadata } from "next";
import Link from "next/link";
import { CalendarClock, History, Wallet } from "lucide-react";

import { requireAccess } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";
import { getBookingConfig, listSessions } from "@/lib/server/sessions";
import { getCurrentUser } from "@/lib/server/auth";
import { SessionCard } from "@/components/sessions/session-card";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = { title: "My Sessions" };

export default async function SessionsPage() {
  await requireAccess(FEATURES.SESSION_BOOKING);

  const [{ config, balance }, upcoming, past, currentUser] = await Promise.all([
    getBookingConfig(),
    listSessions("upcoming"),
    listSessions("past"),
    getCurrentUser(),
  ]);

  return (
    <main className="page-container">
      <div className="page-header">
        <div>
          <h1 className="page-title">My Sessions</h1>
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

      <section className="flex flex-col gap-4">
        <h2 className="section-title">Upcoming</h2>
        {upcoming.length === 0 ? (
          <div className="empty-state">
            <CalendarClock aria-hidden className="empty-state-icon" />
            <p className="font-medium text-muted-foreground">No upcoming sessions.</p>
          </div>
        ) : (
          <div className="card-grid">
            {upcoming.map((session) => (
              <SessionCard
                key={session.id}
                session={session}
                viewerIsMentor={session.mentor_id === currentUser?.id}
              />
            ))}
          </div>
        )}
      </section>

      <section className="mt-10 flex flex-col gap-4">
        <h2 className="section-title">Past</h2>
        {past.length === 0 ? (
          <div className="empty-state">
            <History aria-hidden className="empty-state-icon" />
            <p className="font-medium text-muted-foreground">No past sessions yet.</p>
          </div>
        ) : (
          <div className="card-grid">
            {past.map((session) => (
              <SessionCard
                key={session.id}
                session={session}
                viewerIsMentor={session.mentor_id === currentUser?.id}
              />
            ))}
          </div>
        )}
      </section>
    </main>
  );
}
