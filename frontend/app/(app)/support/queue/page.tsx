import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Inbox } from "lucide-react";
import { cn } from "@/lib/utils";
import { Badge } from "@/components/ui/badge";
import { TicketChatPanel } from "@/components/support/ticket-chat-panel";
import { getMyPermissions } from "@/lib/server/permissions";
import { getCurrentUser } from "@/lib/server/auth";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { getAllSupportTickets, getSupportTicket } from "@/lib/server/support";
import { SUPPORT_TICKET_STATUS_OPTIONS } from "@/lib/constants";
import type { SupportTicketStatus } from "@/lib/constants";
import { SUPPORT_STATUS_VARIANT, SUPPORT_PRIORITY_VARIANT, categoryLabel, formatDate } from "@/lib/support/format";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = { title: "Support Queue" };

interface Props {
  searchParams: Promise<{ status?: string; ticket?: string }>;
}

const FILTERS = [{ label: "All", value: "" }, ...SUPPORT_TICKET_STATUS_OPTIONS];

export default async function SupportQueuePage({ searchParams }: Props) {
  const permissions = await getMyPermissions();
  if (!permissions.includes(PERMISSIONS.SUPPORT.MANAGE)) notFound();

  const { status: rawStatus, ticket: ticketId } = await searchParams;
  const status = FILTERS.some((f) => f.value === rawStatus) ? rawStatus : undefined;
  const basePath = status ? `${ROUTES.SUPPORT_QUEUE}?status=${status}` : ROUTES.SUPPORT_QUEUE;

  const [tickets, currentUser, ticket] = await Promise.all([
    getAllSupportTickets(status as SupportTicketStatus | undefined),
    getCurrentUser(),
    ticketId ? getSupportTicket(ticketId).catch(() => null) : Promise.resolve(null),
  ]);

  function rowHref(id: string): string {
    return status ? `${ROUTES.SUPPORT_QUEUE}?status=${status}&ticket=${id}` : `${ROUTES.SUPPORT_QUEUE}?ticket=${id}`;
  }

  return (
    <main className="page-container">
      <div className="mb-6 flex flex-col gap-2">
        <h1 className="page-title">Support queue</h1>
        <p className="text-muted-foreground">Every support ticket raised across the org.</p>
      </div>

      <nav aria-label="Filter by status" className="mb-6 flex flex-wrap gap-1 border-b border-border">
        {FILTERS.map((f) => {
          const isActive = (status ?? "") === f.value;
          return (
            <Link
              className={cn(
                "px-3 py-2 text-sm font-medium border-b-2 -mb-px transition-colors duration-fast",
                isActive ? "text-primary border-primary" : "text-muted-foreground border-transparent hover:text-foreground",
              )}
              href={f.value ? `${ROUTES.SUPPORT_QUEUE}?status=${f.value}` : ROUTES.SUPPORT_QUEUE}
              key={f.value || "all"}
            >
              {f.label}
            </Link>
          );
        })}
      </nav>

      {tickets.length === 0 ? (
        <div className="empty-state py-16">
          <Inbox aria-hidden className="h-12 w-12 text-muted-foreground" />
          <p className="mt-3 text-sm text-muted-foreground">No tickets match this filter.</p>
        </div>
      ) : (
        <div className="table-responsive">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-xs text-muted-foreground">
                <th className="pb-2 font-medium">Subject</th>
                <th className="pb-2 font-medium">Category</th>
                <th className="pb-2 font-medium">Priority</th>
                <th className="pb-2 font-medium">Status</th>
                <th className="pb-2 font-medium">Updated</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {tickets.map((t) => (
                <tr className="whitespace-nowrap" key={t.id}>
                  <td className="max-w-xs truncate whitespace-normal py-2.5 pr-4">
                    <Link className="font-medium text-foreground hover:text-primary" href={rowHref(t.id)}>
                      {t.subject}
                    </Link>
                  </td>
                  <td className="py-2.5 pr-4 text-muted-foreground">{categoryLabel(t.category)}</td>
                  <td className="py-2.5 pr-4">
                    <Badge variant={SUPPORT_PRIORITY_VARIANT[t.priority]}>{t.priority}</Badge>
                  </td>
                  <td className="py-2.5 pr-4">
                    <Badge variant={SUPPORT_STATUS_VARIANT[t.status]}>{t.status.replace("_", " ")}</Badge>
                  </td>
                  <td className="py-2.5 text-muted-foreground">{formatDate(t.updated_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <TicketChatPanel
        canManage
        basePath={basePath}
        currentUserId={currentUser?.id}
        messages={ticket?.messages ?? []}
        ticket={ticket}
      />
    </main>
  );
}
