import type { Metadata } from "next";
import Link from "next/link";
import { Inbox } from "lucide-react";
import { cn } from "@/lib/utils";
import { Badge } from "@/components/ui/badge";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { TicketChatPanel } from "@/components/tickets/ticket-chat-panel";
import { getTicket, getTicketQueue } from "@/lib/server/tickets";
import { getCurrentUser } from "@/lib/server/auth";
import { requireAnyPermission } from "@/lib/server/permissions";
import { TICKET_STATUS_VARIANT, TICKET_PRIORITY_VARIANT, categoryLabel, formatDate } from "@/lib/tickets/format";
import { SUPPORT_STATUS_OPTIONS, TICKET_KIND } from "@/lib/constants";
import type { TicketStatus } from "@/lib/constants";
import ROUTES from "@/lib/routes";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import { PageHeader } from "@/components/shared/page-header";

export const metadata: Metadata = {
  title: "Support Queue",
  description: "Every support ticket raised across the org.",
};

interface SupportQueuePageProps {
  searchParams: Promise<{ ticket?: string; status?: string }>;
}

const STATUS_FILTERS = [{ label: "All", value: "" }, ...SUPPORT_STATUS_OPTIONS];

export default async function SupportQueuePage({ searchParams }: SupportQueuePageProps) {
  await requireAnyPermission([PERMISSIONS.SUPPORT.MANAGE]);
  const { ticket: ticketId, status: rawStatus } = await searchParams;
  const status = STATUS_FILTERS.some((f) => f.value === rawStatus) ? rawStatus : undefined;
  const basePath = status ? `${ROUTES.SUPPORT_QUEUE}?status=${status}` : ROUTES.SUPPORT_QUEUE;

  const [tickets, currentUser, ticket] = await Promise.all([
    getTicketQueue(TICKET_KIND.SUPPORT, { status: status as TicketStatus | undefined }),
    getCurrentUser(),
    ticketId ? getTicket(ticketId).catch(() => null) : Promise.resolve(null),
  ]);

  function rowHref(id: string): string {
    return `${basePath}${basePath.includes("?") ? "&" : "?"}ticket=${id}`;
  }

  return (
    <main className="page-container">
      <PageHeader description="Every support ticket raised across the org." title="Support Queue" />

      <nav aria-label="Filter by status" className="mb-6 flex flex-wrap gap-1">
        {STATUS_FILTERS.map((f) => (
          <Link
            className={cn(
              "rounded-full px-3 py-1 text-xs font-medium transition-colors duration-fast",
              (status ?? "") === f.value
                ? "bg-primary text-primary-foreground"
                : "bg-muted text-muted-foreground hover:text-foreground",
            )}
            href={f.value ? `${ROUTES.SUPPORT_QUEUE}?status=${f.value}` : ROUTES.SUPPORT_QUEUE}
            key={f.value || "all"}
          >
            {f.label}
          </Link>
        ))}
      </nav>

      {tickets.length === 0 ? (
        <div className="empty-state py-16">
          <Inbox aria-hidden className="h-12 w-12 text-muted-foreground" />
          <p className="mt-3 text-sm text-muted-foreground">No tickets match this filter.</p>
        </div>
      ) : (
        <ResponsiveTable>
          <table className="w-full text-sm">
            <thead>
              <tr className="whitespace-nowrap border-b border-border text-left text-xs text-muted-foreground">
                <th className="pb-2 font-medium">Subject</th>
                <th className="pb-2 font-medium">Category</th>
                <th className="pb-2 font-medium">Priority</th>
                <th className="pb-2 font-medium">Status</th>
                <th className="pb-2 font-medium">Opened</th>
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
                  <td className="py-2.5 pr-4 text-muted-foreground">{categoryLabel(t.category ?? "other")}</td>
                  <td className="py-2.5 pr-4">
                    <Badge variant={TICKET_PRIORITY_VARIANT[t.priority ?? "normal"]}>{t.priority}</Badge>
                  </td>
                  <td className="py-2.5 pr-4">
                    <Badge variant={TICKET_STATUS_VARIANT[t.status]}>{t.status.replace("_", " ")}</Badge>
                  </td>
                  <td className="py-2.5 text-muted-foreground">{formatDate(t.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </ResponsiveTable>
      )}

      <TicketChatPanel basePath={basePath} canManage currentUserId={currentUser?.id} ticket={ticket} />
    </main>
  );
}
