import type { Metadata } from "next";
import Link from "next/link";
import { LifeBuoy, ArrowRight, UserCheck, Inbox } from "lucide-react";
import { cn } from "@/lib/utils";
import { Badge } from "@/components/ui/badge";
import { Can } from "@/components/auth/can";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { CreateTicketDialog } from "@/components/tickets/create-ticket-dialog";
import { TicketChatPanel } from "@/components/tickets/ticket-chat-panel";
import { getMyTickets, getTicket, getTicketQueue } from "@/lib/server/tickets";
import { getCurrentUser } from "@/lib/server/auth";
import { getMyPermissions } from "@/lib/server/permissions";
import { TICKET_STATUS_VARIANT, TICKET_PRIORITY_VARIANT, categoryLabel, formatDate } from "@/lib/tickets/format";
import { SUPPORT_STATUS_OPTIONS, TICKET_KIND } from "@/lib/constants";
import type { TicketStatus } from "@/lib/constants";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Help & Support",
  description: "Raise a support ticket, or track your mentor requests, and their replies.",
};

interface SupportPageProps {
  searchParams: Promise<{ ticket?: string; view?: string; status?: string }>;
}

const VIEW_FILTERS = [{ label: "All", value: "" }, ...SUPPORT_STATUS_OPTIONS];

export default async function SupportPage({ searchParams }: SupportPageProps) {
  const { ticket: ticketId, view: rawView, status: rawStatus } = await searchParams;
  const permissions = await getMyPermissions();
  const canManage = permissions.includes(PERMISSIONS.SUPPORT.MANAGE);
  const view = canManage && rawView === "queue" ? "queue" : "mine";
  const status = view === "queue" && VIEW_FILTERS.some((f) => f.value === rawStatus) ? rawStatus : undefined;

  const basePath =
    view === "queue"
      ? status
        ? `${ROUTES.SUPPORT}?view=queue&status=${status}`
        : `${ROUTES.SUPPORT}?view=queue`
      : ROUTES.SUPPORT;

  const [tickets, currentUser, ticket] = await Promise.all([
    view === "queue" ? getTicketQueue(TICKET_KIND.SUPPORT, { status: status as TicketStatus | undefined }) : getMyTickets(),
    getCurrentUser(),
    ticketId ? getTicket(ticketId).catch(() => null) : Promise.resolve(null),
  ]);

  function rowHref(id: string): string {
    return `${basePath}${basePath.includes("?") ? "&" : "?"}ticket=${id}`;
  }

  return (
    <main className="page-container">
      <div className="page-header">
        <div>
          <h1 className="page-title">Help & Support</h1>
          <p className="text-muted-foreground">
            {view === "queue"
              ? "Every support ticket raised across the org."
              : "Raise a ticket for anything — billing, a bug, your account, course content — or track a mentor request."}
          </p>
        </div>
        {view === "mine" && <CreateTicketDialog />}
      </div>

      <Can permission={PERMISSIONS.SUPPORT.MANAGE}>
        <nav aria-label="Support view" className="mb-6 flex flex-wrap gap-1 border-b border-border">
          <Link
            className={cn(
              "px-3 py-2 text-sm font-medium border-b-2 -mb-px transition-colors duration-fast",
              view === "mine" ? "text-primary border-primary" : "text-muted-foreground border-transparent hover:text-foreground",
            )}
            href={ROUTES.SUPPORT}
          >
            My tickets
          </Link>
          <Link
            className={cn(
              "px-3 py-2 text-sm font-medium border-b-2 -mb-px transition-colors duration-fast",
              view === "queue" ? "text-primary border-primary" : "text-muted-foreground border-transparent hover:text-foreground",
            )}
            href={`${ROUTES.SUPPORT}?view=queue`}
          >
            Queue
          </Link>
        </nav>
      </Can>

      {view === "queue" ? (
        <>
          <nav aria-label="Filter by status" className="mb-6 flex flex-wrap gap-1">
            {VIEW_FILTERS.map((f) => (
              <Link
                className={cn(
                  "rounded-full px-3 py-1 text-xs font-medium transition-colors duration-fast",
                  (status ?? "") === f.value
                    ? "bg-primary text-primary-foreground"
                    : "bg-muted text-muted-foreground hover:text-foreground",
                )}
                href={f.value ? `${ROUTES.SUPPORT}?view=queue&status=${f.value}` : `${ROUTES.SUPPORT}?view=queue`}
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
            <div className="table-responsive">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border text-left text-xs text-muted-foreground">
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
            </div>
          )}
        </>
      ) : tickets.length === 0 ? (
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

      <TicketChatPanel basePath={basePath} canManage={canManage} currentUserId={currentUser?.id} ticket={ticket} />
    </main>
  );
}
