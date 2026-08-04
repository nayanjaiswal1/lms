"use client";

import { useRouter } from "next/navigation";
import { LifeBuoy } from "lucide-react";
import { cn } from "@/lib/utils";
import { Badge } from "@/components/ui/badge";
import { LessonFloatingPanel } from "@/components/shared/lesson-floating-panel";
import { SupportComposer } from "@/components/support/support-composer";
import { TicketStatusSelect } from "@/components/support/ticket-status-select";
import { TicketPropertiesSelect } from "@/components/support/ticket-properties-select";
import { SUPPORT_STATUS_VARIANT, SUPPORT_PRIORITY_VARIANT, categoryLabel } from "@/lib/support/format";
import type { SupportTicket, SupportMessage } from "@/lib/server/support";

interface TicketChatPanelProps {
  ticket: SupportTicket | null;
  messages: SupportMessage[];
  currentUserId?: string;
  canManage: boolean;
  /** Path to return to (strips the ?ticket= param) when the panel closes. */
  basePath: string;
}

// A ticket's thread opens as a floating chat window — the same corner-panel
// shell used by "My notes" and "AI Explanation" (LessonFloatingPanel) — not
// its own page/route and not a full-height side drawer, so replying feels
// like the chatbot widgets already used elsewhere in the app.
export function TicketChatPanel({ ticket, messages, currentUserId, canManage, basePath }: TicketChatPanelProps) {
  const router = useRouter();
  if (!ticket) return null;

  return (
    <LessonFloatingPanel
      ariaLabel={`Ticket: ${ticket.subject}`}
      footer={
        <div className="w-full">
          {ticket.status === "closed" ? (
            <p className="text-xs text-muted-foreground">
              This ticket is closed.{canManage ? " Reopen it above to keep the conversation going." : ""}
            </p>
          ) : (
            <SupportComposer ticketId={ticket.id} />
          )}
        </div>
      }
      headerExtra={
        !canManage && (
          <Badge className="h-5 px-1.5 text-xs" variant={SUPPORT_STATUS_VARIANT[ticket.status]}>
            {ticket.status.replace("_", " ")}
          </Badge>
        )
      }
      icon={<LifeBuoy aria-hidden className="size-4 text-muted-foreground" />}
      title={ticket.subject}
      onClose={() => router.push(basePath)}
    >
      {canManage ? (
        <div className="shrink-0 flex flex-col gap-2 px-4 pt-3">
          <TicketStatusSelect status={ticket.status} ticketId={ticket.id} />
          <TicketPropertiesSelect category={ticket.category} priority={ticket.priority} ticketId={ticket.id} />
        </div>
      ) : (
        <div className="shrink-0 flex flex-wrap items-center gap-1.5 px-4 pt-3">
          <Badge variant={SUPPORT_PRIORITY_VARIANT[ticket.priority]}>{ticket.priority} priority</Badge>
          <span className="text-xs text-muted-foreground">{categoryLabel(ticket.category)}</span>
        </div>
      )}

      <div className="min-h-0 flex-1 overflow-y-auto px-4 py-3">
        {messages.length === 0 ? (
          <p className="text-sm text-muted-foreground">No messages yet.</p>
        ) : (
          <ol aria-label="Ticket messages" className="flex flex-col gap-3">
            {messages.map((msg) => {
              const isMine = msg.sender_id === currentUserId;
              return (
                <li className={cn("flex", isMine ? "justify-end" : "justify-start")} key={msg.id}>
                  <div
                    className={cn(
                      "max-w-[85%] rounded-lg px-3 py-2 text-sm",
                      isMine ? "bg-primary text-primary-foreground" : "bg-muted text-foreground",
                    )}
                  >
                    <p className="whitespace-pre-wrap">{msg.body}</p>
                    <p className={cn("mt-1 text-[10px]", isMine ? "text-primary-foreground/70" : "text-muted-foreground")}>
                      {new Date(msg.created_at).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" })}
                    </p>
                  </div>
                </li>
              );
            })}
          </ol>
        )}
      </div>
    </LessonFloatingPanel>
  );
}
