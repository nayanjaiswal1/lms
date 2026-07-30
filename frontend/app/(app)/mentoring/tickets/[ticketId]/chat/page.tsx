import { notFound } from "next/navigation";
import Link from "next/link";
import { ArrowLeft, MessageSquare } from "lucide-react";
import { cn } from "@/lib/utils";
import { MentorChatComposer } from "@/components/mentoring/mentor-chat-composer";
import { ScheduleSessionButton } from "@/app/(app)/mentoring/tickets/[ticketId]/chat/schedule-session-button";
import { getMentorChatMessages, getMentorTicketById } from "@/lib/server/mentoring";
import { getCurrentUser } from "@/lib/server/auth";
import ROUTES from "@/lib/routes";

export const metadata = { title: "Mentor Chat — MindForge" };

interface Props {
  params: Promise<{ ticketId: string }>;
}

export default async function MentorTicketChatPage({ params }: Props) {
  const { ticketId } = await params;

  const [messages, currentUser, ticket] = await Promise.all([
    getMentorChatMessages(ticketId).catch(() => null),
    getCurrentUser(),
    getMentorTicketById(ticketId),
  ]);

  if (messages === null) notFound();

  return (
    <main className="page-container-sm">
      <div className="mb-6 flex items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <Link className="text-muted-foreground hover:text-foreground" href={ROUTES.MENTORING_TICKETS}>
            <ArrowLeft aria-label="Back to tickets" className="h-5 w-5" />
          </Link>
          <h1 className="page-title">Mentor chat</h1>
        </div>
        {ticket && <ScheduleSessionButton studentId={ticket.student_id} />}
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
