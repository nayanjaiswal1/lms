"use client";

import { useRouter } from "next/navigation";
import { LifeBuoy } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { LessonFloatingPanel } from "@/components/shared/lesson-floating-panel";
import { TicketComposer } from "@/components/tickets/ticket-composer";
import { TicketThread } from "@/components/tickets/ticket-thread";
import { TicketStatusSelect } from "@/components/tickets/ticket-status-select";
import { TicketPropertiesSelect } from "@/components/tickets/ticket-properties-select";
import { TICKET_STATUS_VARIANT, TICKET_PRIORITY_VARIANT, categoryLabel } from "@/lib/tickets/format";
import type { TicketDetail } from "@/lib/server/tickets";

interface TicketChatPanelProps {
  ticket: TicketDetail | null;
  currentUserId?: string;
  canManage: boolean;
  /** Path to return to (strips the ?ticket= param) when the panel closes. */
  basePath: string;
}

// A support ticket's thread opens as a floating chat window — the same
// corner-panel shell used by "My notes" and "AI Explanation"
// (LessonFloatingPanel) — not its own page/route and not a full-height side
// drawer, so replying feels like the chatbot widgets already used elsewhere
// in the app. Support-ticket-only: mentorship tickets use a full chat page
// instead (app/(app)/mentoring/tickets/[ticketId]/chat) since that surface
// also carries a breadcrumb and a session-booking CTA.
export function TicketChatPanel({ ticket, currentUserId, canManage, basePath }: TicketChatPanelProps) {
  const router = useRouter();
  if (!ticket) return null;

  const category = ticket.category ?? "other";
  const priority = ticket.priority ?? "normal";

  return (
    <LessonFloatingPanel
      ariaLabel={`Ticket: ${ticket.subject ?? "Untitled"}`}
      footer={
        <div className="w-full">
          {ticket.status === "closed" ? (
            <p className="text-xs text-muted-foreground">
              This ticket is closed.{canManage ? " Reopen it above to keep the conversation going." : ""}
            </p>
          ) : (
            <TicketComposer ticketId={ticket.id} />
          )}
        </div>
      }
      headerExtra={
        !canManage && (
          <Badge className="h-5 px-1.5 text-xs" variant={TICKET_STATUS_VARIANT[ticket.status]}>
            {ticket.status.replace("_", " ")}
          </Badge>
        )
      }
      icon={<LifeBuoy aria-hidden className="size-4 text-muted-foreground" />}
      title={ticket.subject ?? "Untitled"}
      onClose={() => router.push(basePath)}
    >
      {canManage ? (
        <div className="shrink-0 flex flex-col gap-2 px-4 pt-3">
          <TicketStatusSelect status={ticket.status} ticketId={ticket.id} />
          <TicketPropertiesSelect category={category} priority={priority} ticketId={ticket.id} />
        </div>
      ) : (
        <div className="shrink-0 flex flex-wrap items-center gap-1.5 px-4 pt-3">
          <Badge variant={TICKET_PRIORITY_VARIANT[priority]}>{priority} priority</Badge>
          <span className="text-xs text-muted-foreground">{categoryLabel(category)}</span>
        </div>
      )}

      <div className="min-h-0 flex-1 overflow-y-auto px-4 py-3">
        <TicketThread currentUserId={currentUserId} messages={ticket.messages} />
      </div>
    </LessonFloatingPanel>
  );
}
