import { notFound } from "next/navigation";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { TicketThread } from "@/components/tickets/ticket-thread";
import { TicketComposer } from "@/components/tickets/ticket-composer";
import { BookSessionDialog } from "@/components/sessions/book-session-dialog";
import { AccessGate } from "@/components/shared/access-gate";
import { FEATURES } from "@/lib/features";
import { getBookingConfig } from "@/lib/server/sessions";
import { getTicket } from "@/lib/server/tickets";
import { getCurrentUser } from "@/lib/server/auth";
import { truncateId } from "@/lib/tickets/format";
import ROUTES from "@/lib/routes";

export const metadata = { title: "Mentor Chat" };

interface Props {
  params: Promise<{ ticketId: string }>;
}

export default async function MentorTicketChatPage({ params }: Props) {
  const { ticketId } = await params;

  const [ticket, currentUser, bookingConfig] = await Promise.all([
    getTicket(ticketId).catch(() => null),
    getCurrentUser(),
    // Booking may be off for this org, in which case the CTA simply doesn't
    // render — a failed config read must not take the chat page down with it.
    getBookingConfig().catch(() => null),
  ]);

  if (ticket === null) notFound();

  return (
    <main className="page-container-sm">
      <Breadcrumb
        items={[
          { label: "Mentoring Tickets", href: ROUTES.MENTORING_TICKETS },
          { label: `Ticket ${truncateId(ticketId)}`, href: ROUTES.mentoringTicketDetail(ticketId) },
          { label: "Chat" },
        ]}
      />

      <div className="mb-6 flex items-center justify-between gap-3">
        <h1 className="section-title">Mentor chat</h1>
        {/* Only the assigned mentor schedules from here, and only through the
            booking flow — the old ad-hoc dialog wrote a calendar event
            directly, skipping availability, the upcoming-session cap, and
            credits entirely. */}
        {ticket.assigned_to && currentUser?.id === ticket.assigned_to && (
          <AccessGate feature={FEATURES.SESSION_BOOKING} mode="hide">
            <BookSessionDialog
              balance={bookingConfig?.balance ?? 0}
              defaultDurationMinutes={bookingConfig?.config.default_duration_minutes ?? 30}
              mentorId={ticket.assigned_to}
              mentorName="you"
              requireCredits={false}
              studentId={ticket.requester_id}
              triggerLabel="Schedule session"
            />
          </AccessGate>
        )}
      </div>

      <div className="mb-6">
        <TicketThread currentUserId={currentUser?.id} messages={ticket.messages} />
      </div>

      <TicketComposer placeholder="Write a message…" ticketId={ticketId} />
    </main>
  );
}
