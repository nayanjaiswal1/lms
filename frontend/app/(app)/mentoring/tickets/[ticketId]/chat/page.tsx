import { notFound } from "next/navigation";
import { MessageSquare } from "lucide-react";
import { cn } from "@/lib/utils";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { MentorChatComposer } from "@/components/mentoring/mentor-chat-composer";
import { BookSessionDialog } from "@/components/sessions/book-session-dialog";
import { AccessGate } from "@/components/shared/access-gate";
import { FEATURES } from "@/lib/features";
import { getBookingConfig } from "@/lib/server/sessions";
import { getMentorChatMessages, getMentorTicketById } from "@/lib/server/mentoring";
import { getCurrentUser } from "@/lib/server/auth";
import { truncateId } from "@/lib/mentoring/format";
import ROUTES from "@/lib/routes";

export const metadata = { title: "Mentor Chat" };

interface Props {
  params: Promise<{ ticketId: string }>;
}

export default async function MentorTicketChatPage({ params }: Props) {
  const { ticketId } = await params;

  const [messages, currentUser, ticket, bookingConfig] = await Promise.all([
    getMentorChatMessages(ticketId).catch(() => null),
    getCurrentUser(),
    getMentorTicketById(ticketId),
    // Booking may be off for this org, in which case the CTA simply doesn't
    // render — a failed config read must not take the chat page down with it.
    getBookingConfig().catch(() => null),
  ]);

  if (messages === null) notFound();

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
        {ticket?.assigned_mentor_id && currentUser?.id === ticket.assigned_mentor_id && (
          <AccessGate feature={FEATURES.SESSION_BOOKING} mode="hide">
            <BookSessionDialog
              balance={bookingConfig?.balance ?? 0}
              defaultDurationMinutes={bookingConfig?.config.default_duration_minutes ?? 30}
              mentorId={ticket.assigned_mentor_id}
              mentorName="you"
              requireCredits={false}
              studentId={ticket.student_id}
              triggerLabel="Schedule session"
            />
          </AccessGate>
        )}
      </div>

      {messages.length === 0 ? (
        <div className="empty-state py-12">
          <MessageSquare aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="mt-3 text-sm text-muted-foreground">No messages yet. Say hello!</p>
        </div>
      ) : (
        <ol aria-label="Chat messages" className="mb-6 flex flex-col gap-3">
          {messages.map((msg) => {
            const isMine = msg.sender_id === currentUser?.id;
            return (
              <li className={cn("flex", isMine ? "justify-end" : "justify-start")} key={msg.id}>
                <div
                  className={cn(
                    "max-w-[80%] rounded-lg px-4 py-2.5 text-sm",
                    isMine ? "bg-primary text-primary-foreground" : "bg-muted text-foreground",
                  )}
                >
                  <p className="whitespace-pre-wrap">{msg.body}</p>
                  <p
                    className={cn(
                      "mt-1 text-xs",
                      isMine ? "text-primary-foreground/70" : "text-muted-foreground",
                    )}
                  >
                    {new Date(msg.created_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
                  </p>
                </div>
              </li>
            );
          })}
        </ol>
      )}

      <MentorChatComposer ticketId={ticketId} />
    </main>
  );
}
