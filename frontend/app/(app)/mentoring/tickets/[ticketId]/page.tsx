import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { Can } from "@/components/auth/can";
import { UserLink } from "@/components/shared/user-link";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { ClaimTicketButton } from "@/components/mentoring/claim-ticket-button";
import { CloseTicketButton } from "@/components/mentoring/close-ticket-button";
import { AssignTicketControl } from "@/components/mentoring/assign-ticket-control";
import { IssueCertificateControl } from "@/components/mentoring/issue-certificate-control";
import { ChangeRequestReviewControls } from "@/components/mentoring/change-request-review-controls";
import { ResolveReportControl } from "@/components/mentoring/resolve-report-control";
import { LifecycleRecordCard } from "@/components/mentoring/lifecycle-record-card";
import { getMentorTicketDetail, getMentors } from "@/lib/server/mentoring";
import { getCurrentUser } from "@/lib/server/auth";
import { TICKET_STATUS_VARIANT, ESCALATION_LABEL, truncateId, formatDateTime } from "@/lib/tickets/format";
import { CHANGE_REQUEST_STATUS_VARIANT, REPORT_STATUS_VARIANT } from "@/lib/mentoring/format";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ ticketId: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { ticketId } = await params;
  return { title: "Ticket detail", alternates: { canonical: `/mentoring/tickets/${ticketId}` } };
}

// One event, one ordering rule — the single timeline the lifecycle view
// renders, merged from change-requests/reports instead of two separately-
// sorted lists on the page. There's no durable assignment-history record in
// the schema (assigned_to is overwritten in place, no timestamp kept), so
// "currently assigned to" is shown as a standalone fact near the status
// badge instead of a fabricated timeline entry.
interface LifecycleEvent {
  at: string;
  label: string;
  detail?: string;
}

export default async function TicketDetailPage({ params }: Props) {
  const { ticketId } = await params;

  const [detail, mentors, currentUser] = await Promise.all([
    getMentorTicketDetail(ticketId),
    getMentors(),
    getCurrentUser(),
  ]);

  const { ticket, change_requests: changeRequests, reports } = detail;
  const mentorNameById = new Map(mentors.map((m) => [m.user_id, m.name]));
  const isOwnTicket = ticket.assigned_to === currentUser?.id;
  const assignedMentorName = ticket.assigned_to ? mentorNameById.get(ticket.assigned_to) ?? truncateId(ticket.assigned_to) : null;

  const events: LifecycleEvent[] = [
    { at: ticket.created_at, label: "Requested" },
    ...changeRequests.map((cr) => ({
      at: cr.created_at,
      label: `Change requested (${cr.status})`,
      detail: cr.reason,
    })),
    ...(reports ?? []).map((rep) => ({
      at: rep.created_at,
      label: `Report filed (${rep.status})`,
      detail: rep.description,
    })),
    ...(ticket.closed_at ? [{ at: ticket.closed_at, label: "Closed" }] : []),
  ].sort((a, b) => new Date(a.at).getTime() - new Date(b.at).getTime());

  return (
    <main className="page-container-sm">
      <Breadcrumb
        items={[
          { label: "Mentoring Tickets", href: ROUTES.MENTORING_TICKETS },
          { label: `Ticket ${truncateId(ticket.id)}` },
        ]}
      />

      <div className="mb-8 flex flex-wrap items-center justify-between gap-4">
        <div className="flex flex-col gap-1">
          <h1 className="section-title">Ticket {truncateId(ticket.id)}</h1>
          <p className="text-muted-foreground">
            Student{" "}
            <UserLink className="hover:text-foreground hover:underline" userId={ticket.requester_id}>
              {truncateId(ticket.requester_id)}
            </UserLink>
            {" "}· Course {ticket.course_id ? truncateId(ticket.course_id) : "—"}
            {assignedMentorName && ticket.assigned_to && (
              <>
                {" "}· Mentor{" "}
                <UserLink className="hover:text-foreground hover:underline" userId={ticket.assigned_to}>
                  {assignedMentorName}
                </UserLink>
              </>
            )}
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-1.5">
          <Badge variant={TICKET_STATUS_VARIANT[ticket.status] ?? "outline"}>{ticket.status}</Badge>
          {ticket.status === "open" && ticket.escalation_level > 0 && (
            <Badge variant="destructive">{ESCALATION_LABEL[ticket.escalation_level]}</Badge>
          )}
        </div>
      </div>

      <div className="card-base mb-8 flex flex-wrap items-center gap-2 p-6">
        {ticket.status === "open" && (
          <>
            <ClaimTicketButton ticketId={ticket.id} />
            <Can permission={PERMISSIONS.MENTORING.ASSIGN_TICKETS}>
              <AssignTicketControl
                mentors={mentors.map((m) => ({ user_id: m.user_id, name: m.name }))}
                ticketId={ticket.id}
              />
            </Can>
          </>
        )}
        {ticket.status === "assigned" && (
          <>
            <Link href={ROUTES.mentoringTicketChat(ticket.id)}>
              <Button size="sm" variant="outline">Chat</Button>
            </Link>
            {isOwnTicket ? (
              <>
                <CloseTicketButton ticketId={ticket.id} />
                {ticket.course_id && <IssueCertificateControl courseId={ticket.course_id} studentId={ticket.requester_id} />}
              </>
            ) : (
              <Can permission={PERMISSIONS.MENTORING.ASSIGN_TICKETS}>
                <CloseTicketButton ticketId={ticket.id} />
                {ticket.course_id && <IssueCertificateControl courseId={ticket.course_id} studentId={ticket.requester_id} />}
              </Can>
            )}
          </>
        )}
        {ticket.status === "closed" && (
          <>
            <p className="text-sm text-muted-foreground">This ticket is closed.</p>
            {ticket.course_id && (
              isOwnTicket ? (
                <IssueCertificateControl courseId={ticket.course_id} studentId={ticket.requester_id} />
              ) : (
                <Can permission={PERMISSIONS.MENTORING.ASSIGN_TICKETS}>
                  <IssueCertificateControl courseId={ticket.course_id} studentId={ticket.requester_id} />
                </Can>
              )
            )}
          </>
        )}
      </div>

      <section className="mb-8">
        <h2 className="section-title mb-3">Lifecycle</h2>
        <ol className="flex flex-col gap-3 text-sm">
          {events.map((event, i) => (
            <li
              className="flex items-start justify-between gap-4 border-b border-border pb-3 last:border-0"
              key={i}
            >
              <div className="flex flex-col gap-0.5">
                <span className="text-foreground">{event.label}</span>
                {event.detail && <span className="text-xs text-muted-foreground">{event.detail}</span>}
              </div>
              <span className="shrink-0 text-muted-foreground">{formatDateTime(event.at)}</span>
            </li>
          ))}
        </ol>
      </section>

      {changeRequests.length > 0 && (
        <section className="mb-8">
          <h2 className="section-title mb-3">Mentor change requests</h2>
          <div className="flex flex-col gap-3">
            {changeRequests.map((cr) => (
              <LifecycleRecordCard
                key={cr.id}
                status={cr.status}
                timestamp={cr.created_at}
                variant={CHANGE_REQUEST_STATUS_VARIANT[cr.status] ?? "outline"}
              >
                <p className="text-sm text-foreground">{cr.reason}</p>
                {cr.status === "pending" && (
                  <Can permission={PERMISSIONS.MENTORING.ASSIGN_TICKETS}>
                    <ChangeRequestReviewControls requestId={cr.id} />
                  </Can>
                )}
                {cr.review_note && (
                  <p className="text-xs text-muted-foreground">Review note: {cr.review_note}</p>
                )}
              </LifecycleRecordCard>
            ))}
          </div>
        </section>
      )}

      <Can permission={PERMISSIONS.MENTORING.MANAGE_REPORTS}>
        {reports && reports.length > 0 && (
          <section>
            <h2 className="section-title mb-3">Reports</h2>
            <div className="flex flex-col gap-3">
              {reports.map((rep) => (
                <LifecycleRecordCard
                  key={rep.id}
                  status={rep.status}
                  timestamp={rep.created_at}
                  variant={REPORT_STATUS_VARIANT[rep.status] ?? "outline"}
                >
                  <p className="text-sm text-foreground">
                    <span className="font-medium">{rep.reason}:</span> {rep.description}
                  </p>
                  {rep.status === "open" || rep.status === "reviewing" ? (
                    <ResolveReportControl reportId={rep.id} />
                  ) : (
                    rep.resolution_note && (
                      <p className="text-xs text-muted-foreground">Resolution: {rep.resolution_note}</p>
                    )
                  )}
                </LifecycleRecordCard>
              ))}
            </div>
          </section>
        )}
      </Can>
    </main>
  );
}
