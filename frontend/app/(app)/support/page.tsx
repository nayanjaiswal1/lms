import type { Metadata } from "next";
import Link from "next/link";
import { LifeBuoy, ArrowRight, UserCheck } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { CreateTicketDialog } from "@/components/tickets/create-ticket-dialog";
import { TicketChatPanel } from "@/components/tickets/ticket-chat-panel";
import { getMyTickets, getTicket } from "@/lib/server/tickets";
import { getCurrentUser } from "@/lib/server/auth";
import { getMyPermissions } from "@/lib/server/permissions";
import { TICKET_KIND } from "@/lib/constants";
import { TICKET_STATUS_VARIANT, categoryLabel, formatDate } from "@/lib/tickets/format";
import ROUTES from "@/lib/routes";
import { PageHeader } from "@/components/shared/page-header";

export const metadata: Metadata = {
  title: "Help & Support",
  description: "Raise a support ticket, or track your mentor requests, and their replies.",
};

interface SupportPageProps {
  searchParams: Promise<{ ticket?: string }>;
}

export default async function SupportPage({ searchParams }: SupportPageProps) {
  const { ticket: ticketId } = await searchParams;
  const permissions = await getMyPermissions();
  const canManage = permissions.includes(PERMISSIONS.SUPPORT.MANAGE);

  const [tickets, currentUser, ticket] = await Promise.all([
    getMyTickets(),
    getCurrentUser(),
    ticketId ? getTicket(ticketId).catch(() => null) : Promise.resolve(null),
  ]);

  function rowHref(id: string): string {
    return `${ROUTES.SUPPORT}?ticket=${id}`;
  }

  return (
    <main className="page-container">
      <PageHeader
        description="Raise a ticket for anything — billing, a bug, your account, course content — or track a mentor request."
        title="Help & Support"
      >
        <CreateTicketDialog />
      </PageHeader>

      {tickets.length === 0 ? (
        <div className="empty-state">
          <LifeBuoy aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="text-muted-foreground">No tickets yet — raise one if something&apos;s not working.</p>
        </div>
      ) : (
        <div className="flex flex-col gap-3">
          {tickets.map((t) =>
            t.kind === TICKET_KIND.MENTORSHIP ? (
              <Link className="card-interactive flex items-center gap-4 p-4" href={ROUTES.mentoringTicketChat(t.id)} key={t.id}>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-semibold">Mentor request</p>
                  <div className="mt-1.5 flex flex-wrap items-center gap-1.5">
                    <Badge variant={TICKET_STATUS_VARIANT[t.status]}>{t.status.replace("_", " ")}</Badge>
                    <span className="text-xs text-muted-foreground">
                      <UserCheck aria-hidden className="mr-1 inline h-3 w-3" />
                      Mentorship
                    </span>
                    <span className="text-xs text-muted-foreground">· Opened {formatDate(t.created_at)}</span>
                  </div>
                </div>
                <ArrowRight aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
              </Link>
            ) : (
              <Link className="card-interactive flex items-center gap-4 p-4" href={rowHref(t.id)} key={t.id}>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-semibold">{t.subject}</p>
                  <div className="mt-1.5 flex flex-wrap items-center gap-1.5">
                    <Badge variant={TICKET_STATUS_VARIANT[t.status]}>{t.status.replace("_", " ")}</Badge>
                    <span className="text-xs text-muted-foreground">{categoryLabel(t.category ?? "other")}</span>
                    <span className="text-xs text-muted-foreground">· Opened {formatDate(t.created_at)}</span>
                  </div>
                </div>
                <ArrowRight aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
              </Link>
            ),
          )}
        </div>
      )}

      <TicketChatPanel basePath={ROUTES.SUPPORT} canManage={canManage} currentUserId={currentUser?.id} ticket={ticket} />
    </main>
  );
}
