import { Suspense } from "react";
import Link from "next/link";
import { Ticket as TicketIcon } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { Can } from "@/components/auth/can";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { ClaimTicketButton } from "@/components/mentoring/claim-ticket-button";
import { CloseTicketButton } from "@/components/mentoring/close-ticket-button";
import { AssignTicketControl } from "@/components/mentoring/assign-ticket-control";
import { ChangeRequestReviewControls } from "@/components/mentoring/change-request-review-controls";
import { getMentorTickets, getMentors, getMentorChangeRequests } from "@/lib/server/mentoring";
import { getCurrentUser } from "@/lib/server/auth";
import { TICKET_STATUS_VARIANT, ESCALATION_LABEL, truncateId, formatDate } from "@/lib/mentoring/format";
import ROUTES from "@/lib/routes";

export const metadata = { title: "Mentor Ticket Queue — MindForge" };

async function TicketQueueContent() {
  const [tickets, mentors, currentUser] = await Promise.all([
    getMentorTickets(),
    getMentors(),
    getCurrentUser(),
  ]);

  const openAndAssigned = tickets.filter((t) => t.status !== "closed");
  const mentorOptions = mentors.map((m) => ({ user_id: m.user_id, name: m.name }));
  const mentorNameById = new Map(mentors.map((m) => [m.user_id, m.name]));

  if (openAndAssigned.length === 0) {
    return (
      <div className="empty-state py-16">
        <TicketIcon aria-hidden className="h-12 w-12 text-muted-foreground" />
        <p className="mt-3 text-sm text-muted-foreground">No open or assigned tickets right now.</p>
      </div>
    );
  }

  return (
    <div className="table-responsive">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-border text-left text-xs text-muted-foreground">
            <th className="pb-2 font-medium">Student</th>
            <th className="pb-2 font-medium">Course</th>
            <th className="pb-2 font-medium">Status</th>
            <th className="pb-2 font-medium">Mentor</th>
            <th className="pb-2 font-medium">Opened</th>
            <th className="pb-2 font-medium" />
          </tr>
        </thead>
        <tbody className="divide-y divide-border">
          {openAndAssigned.map((ticket) => {
            const isOwnTicket = ticket.assigned_mentor_id === currentUser?.id;

            return (
              <tr key={ticket.id}>
                <td className="py-2.5 pr-4 font-mono text-xs text-muted-foreground">
                  {truncateId(ticket.student_id)}
                </td>
                <td className="py-2.5 pr-4 font-mono text-xs text-muted-foreground">
                  {truncateId(ticket.course_id)}
                </td>
                <td className="py-2.5 pr-4">
                  <div className="flex flex-wrap items-center gap-1.5">
                    <Badge variant={TICKET_STATUS_VARIANT[ticket.status] ?? "outline"}>{ticket.status}</Badge>
                    {ticket.status === "open" && ticket.escalation_level > 0 && (
                      <Badge variant="destructive">{ESCALATION_LABEL[ticket.escalation_level]}</Badge>
                    )}
                  </div>
                </td>
                <td className="py-2.5 pr-4 text-muted-foreground">
                  {ticket.assigned_mentor_id
                    ? mentorNameById.get(ticket.assigned_mentor_id) ?? truncateId(ticket.assigned_mentor_id)
                    : "—"}
                </td>
                <td className="py-2.5 pr-4 text-muted-foreground">
                  {formatDate(ticket.created_at)}
                </td>
                <td className="py-2.5">
                  <div className="flex flex-wrap items-center justify-end gap-2">
                    <Can permission={PERMISSIONS.MENTORING.ASSIGN_TICKETS}>
                      <Link href={ROUTES.mentoringTicketDetail(ticket.id)}>
                        <Button size="sm" variant="ghost">Details</Button>
                      </Link>
                    </Can>
                    {ticket.status === "open" && (
                      <>
                        <ClaimTicketButton ticketId={ticket.id} />
                        <Can permission={PERMISSIONS.MENTORING.ASSIGN_TICKETS}>
                          <AssignTicketControl mentors={mentorOptions} ticketId={ticket.id} />
                        </Can>
                      </>
                    )}
                    {ticket.status === "assigned" && isOwnTicket && (
                      <Link href={ROUTES.mentoringTicketChat(ticket.id)}>
                        <Button size="sm" variant="outline">Chat</Button>
                      </Link>
                    )}
                    {ticket.status === "assigned" && (
                      isOwnTicket ? (
                        <CloseTicketButton ticketId={ticket.id} />
                      ) : (
                        <Can permission={PERMISSIONS.MENTORING.ASSIGN_TICKETS}>
                          <CloseTicketButton ticketId={ticket.id} />
                        </Can>
                      )
                    )}
                  </div>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

async function ChangeRequestsContent() {
  const requests = await getMentorChangeRequests("pending");

  if (requests.length === 0) return null;

  return (
    <div className="mb-8 flex flex-col gap-3">
      <h2 className="section-title">Pending mentor change requests</h2>
      <div className="table-responsive">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border text-left text-xs text-muted-foreground">
              <th className="pb-2 font-medium">Student</th>
              <th className="pb-2 font-medium">Reason</th>
              <th className="pb-2 font-medium">Requested</th>
              <th className="pb-2 font-medium" />
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {requests.map((req) => (
              <tr key={req.id}>
                <td className="py-2.5 pr-4 font-mono text-xs text-muted-foreground">
                  {truncateId(req.student_id)}
                </td>
                <td className="max-w-xs py-2.5 pr-4 text-foreground">{req.reason}</td>
                <td className="py-2.5 pr-4 text-muted-foreground">
                  {formatDate(req.created_at)}
                </td>
                <td className="py-2.5">
                  <ChangeRequestReviewControls requestId={req.id} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export default function MentorTicketQueuePage() {
  return (
    <main className="page-container">
      <div className="mb-8 flex flex-col gap-2">
        <h1 className="page-title">Mentor ticket queue</h1>
        <p className="text-muted-foreground">Claim open tickets or manage the ones assigned to you.</p>
      </div>
      <Can permission={PERMISSIONS.MENTORING.ASSIGN_TICKETS}>
        <Suspense fallback={<Skeleton className="mb-8 h-32 rounded-lg" />}>
          <ChangeRequestsContent />
        </Suspense>
      </Can>
      <Suspense fallback={<Skeleton className="h-64 rounded-lg" />}>
        <TicketQueueContent />
      </Suspense>
    </main>
  );
}
