import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { ExternalLink } from "lucide-react";

import { Breadcrumb } from "@/components/shared/breadcrumb";
import { SessionStatusBadge } from "@/components/sessions/session-status-badge";
import { CancelSessionDialog } from "@/components/sessions/cancel-session-dialog";
import { SessionOutcomeControl } from "@/components/sessions/session-outcome-control";
import { SessionFeedbackForm } from "@/components/sessions/session-feedback-form";
import { SessionFeedbackList } from "@/components/sessions/session-feedback-list";
import { MentorSessionNotes } from "@/components/sessions/mentor-session-notes";
import { getBookingConfig, getSessionDetail, type SessionDetail } from "@/lib/server/sessions";
import { getCurrentUser } from "@/lib/server/auth";
import { formatSessionRange } from "@/lib/sessions/format";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ sessionId: string }>;
}

export const metadata: Metadata = { title: "Session details" };

export default async function SessionDetailPage({ params }: Props) {
  const { sessionId } = await params;

  let detail: SessionDetail;
  try {
    detail = await getSessionDetail(sessionId);
  } catch {
    notFound();
  }

  const [currentUser, { config }] = await Promise.all([getCurrentUser(), getBookingConfig()]);
  const { session, feedback, notes, my_feedback } = detail;
  const viewerIsMentor = session.mentor_id === currentUser?.id;
  const counterpart = viewerIsMentor
    ? (session.student_name ?? session.batch_name ?? "Student")
    : (session.mentor_name ?? "Mentor");

  return (
    <main className="page-container">
      <Breadcrumb items={[{ label: "Sessions", href: ROUTES.SESSIONS }, { label: session.title }]} />

      <div className="flex flex-col gap-6">
        <section className="flex flex-col gap-3 rounded-xl border border-border bg-card p-6">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <h1 className="page-title">{session.title}</h1>
            <SessionStatusBadge status={session.status} />
          </div>
          <p className="text-sm text-muted-foreground">
            {formatSessionRange(session.starts_at, session.ends_at, "full")}
          </p>
          <p className="text-sm text-foreground">With {counterpart}</p>

          {session.agenda && (
            <div className="mt-2">
              <h2 className="text-sm font-medium text-foreground">Agenda</h2>
              <p className="prose-content mt-1 whitespace-pre-line">{session.agenda}</p>
            </div>
          )}

          {session.meeting_url && (
            <a
              className="flex w-fit items-center gap-1.5 text-sm text-primary hover:underline"
              href={session.meeting_url}
              rel="noopener noreferrer"
              target="_blank"
            >
              <ExternalLink aria-hidden className="h-4 w-4" />
              Join meeting
            </a>
          )}

          {session.status === "cancelled" && session.cancel_reason && (
            <p className="text-sm text-muted-foreground">Cancellation reason: {session.cancel_reason}</p>
          )}

          <div className="mt-2 flex flex-wrap items-center gap-2">
            {session.status === "scheduled" && (
              <CancelSessionDialog
                cancelCutoffHours={config.cancel_cutoff_hours}
                sessionId={session.id}
                startsAt={session.starts_at}
              />
            )}
            {viewerIsMentor && (
              <SessionOutcomeControl sessionId={session.id} startsAt={session.starts_at} status={session.status} />
            )}
          </div>
        </section>

        <div className="rounded-xl border border-border bg-card p-6">
          <SessionFeedbackForm
            endsAt={session.ends_at}
            myFeedback={my_feedback}
            sessionId={session.id}
            status={session.status}
          />
        </div>

        <SessionFeedbackList feedback={feedback} />

        <MentorSessionNotes notes={notes} readOnly={!viewerIsMentor} sessionId={session.id} />
      </div>
    </main>
  );
}
