import type { Metadata } from "next";
import Link from "next/link";
import { LifeBuoy, ArrowRight } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Can } from "@/components/auth/can";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { CreateTicketDialog } from "@/components/support/create-ticket-dialog";
import { TicketChatPanel } from "@/components/support/ticket-chat-panel";
import { getMySupportTickets, getSupportTicket } from "@/lib/server/support";
import { getCurrentUser } from "@/lib/server/auth";
import { getMyPermissions } from "@/lib/server/permissions";
import { SUPPORT_STATUS_VARIANT, categoryLabel, formatDate } from "@/lib/support/format";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Support",
  description: "Raise a support ticket and track its replies.",
};

interface SupportPageProps {
  searchParams: Promise<{ ticket?: string }>;
}

export default async function SupportPage({ searchParams }: SupportPageProps) {
  const { ticket: ticketId } = await searchParams;

  const [tickets, currentUser, permissions, ticket] = await Promise.all([
    getMySupportTickets(),
    getCurrentUser(),
    getMyPermissions(),
    ticketId ? getSupportTicket(ticketId).catch(() => null) : Promise.resolve(null),
  ]);

  const canManage = permissions.includes(PERMISSIONS.SUPPORT.MANAGE);

  return (
    <main className="page-container">
      <div className="page-header">
        <div>
          <h1 className="page-title">Support</h1>
          <p className="text-muted-foreground">Raise a ticket for anything — billing, a bug, your account, course content.</p>
        </div>
        <div className="flex items-center gap-3">
          <Can permission={PERMISSIONS.SUPPORT.MANAGE}>
            <Link className="text-sm text-primary hover:underline" href={ROUTES.SUPPORT_QUEUE}>
              Staff queue
            </Link>
          </Can>
          <CreateTicketDialog />
        </div>
      </div>

      {tickets.length === 0 ? (
        <div className="empty-state">
          <LifeBuoy aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="text-muted-foreground">No tickets yet — raise one if something&apos;s not working.</p>
        </div>
      ) : (
        <div className="flex flex-col gap-3">
          {tickets.map((t) => (
            <Link className="card-interactive flex items-center gap-4 p-4" href={`${ROUTES.SUPPORT}?ticket=${t.id}`} key={t.id}>
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-semibold">{t.subject}</p>
                <div className="mt-1.5 flex flex-wrap items-center gap-1.5">
                  <Badge variant={SUPPORT_STATUS_VARIANT[t.status]}>{t.status.replace("_", " ")}</Badge>
                  <span className="text-xs text-muted-foreground">{categoryLabel(t.category)}</span>
                  <span className="text-xs text-muted-foreground">· Updated {formatDate(t.updated_at)}</span>
                </div>
              </div>
              <ArrowRight aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
            </Link>
          ))}
        </div>
      )}

      <TicketChatPanel
        basePath={ROUTES.SUPPORT}
        canManage={canManage}
        currentUserId={currentUser?.id}
        messages={ticket?.messages ?? []}
        ticket={ticket}
      />
    </main>
  );
}
