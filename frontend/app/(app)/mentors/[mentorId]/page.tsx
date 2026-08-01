import Link from "next/link";
import { notFound } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { MentorHero } from "@/components/mentoring/mentor-hero";
import { ReportMentorDialog } from "@/components/mentoring/report-mentor-dialog";
import { RequestMentorChangeDialog } from "@/components/mentoring/request-mentor-change-dialog";
import { TicketHistoryDialog } from "@/components/mentoring/ticket-history-dialog";
import { ScheduleSessionButton } from "@/components/mentoring/schedule-session-button";
import { MessageMentorButton } from "@/components/mentoring/message-mentor-button";
import { MentorInsightsPanel } from "@/components/mentoring/mentor-insights-panel";
import { MentorMetadataCard } from "@/components/mentoring/mentor-metadata-card";
import { MentorFeedbackSection } from "@/components/mentoring/mentor-feedback-section";
import { MentorReviewsList } from "@/components/mentoring/mentor-reviews-list";
import { getMentorProfile, getMyMentorTickets, getTicketHistory } from "@/lib/server/mentoring";
import { getEnrollments } from "@/lib/server/courses";
import { getMyFeedback, getPublicFeedback } from "@/lib/server/feedback";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ mentorId: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { mentorId } = await params;
  return { title: "Mentor", alternates: { canonical: `/mentors/${mentorId}` } };
}

export default async function MentorProfilePage({ params }: Props) {
  const { mentorId } = await params;

  const [mentor, myFeedback, myTickets, enrollments, reviews] = await Promise.all([
    getMentorProfile(mentorId),
    getMyFeedback("mentor", mentorId).catch(() => null),
    getMyMentorTickets().catch(() => []),
    getEnrollments().catch(() => []),
    getPublicFeedback("mentor", mentorId, 5).catch(() => []),
  ]);

  if (!mentor) notFound();

  // A student can be enrolled in several courses/batches at once, each with
  // its own mentor ticket — this mentor may be assigned on one of several.
  const assignedTicket = myTickets.find(
    (t) => t.status === "assigned" && t.assigned_mentor_id === mentorId,
  );
  const assignedCourse = assignedTicket
    ? enrollments.find((e) => e.course_id === assignedTicket.course_id)?.course
    : undefined;

  // Approximates the backend's HasBeenMentoredBy check (which the feedback
  // service already enforces server-side) so we don't show a rating form or
  // "Report this mentor" to someone browsing a mentor they've never had.
  // mentor_tickets.assigned_mentor_id is cleared on reassignment rather than
  // preserved (see mentoring.Repo.HasBeenMentoredBy), so this misses the rare
  // case where a mentor was later swapped out — that edge case has no
  // student-facing endpoint to check today, and Submit() still rejects it
  // server-side if this approximation is ever too permissive.
  const hasMentorshipHistory = myTickets.some((t) => t.assigned_mentor_id === mentorId);

  const history = assignedTicket ? await getTicketHistory(assignedTicket.id).catch(() => null) : null;

  return (
    <main className="page-container">
      <Breadcrumb items={[{ label: "Mentors", href: ROUTES.MENTORS }, { label: mentor.name }]} />

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
        <div className="flex flex-col gap-6 lg:col-span-8">
          <MentorHero
            assignedCourse={assignedCourse}
            canReport={hasMentorshipHistory}
            isYourMentor={Boolean(assignedTicket)}
            mentor={mentor}
            ticketId={assignedTicket?.id}
          />

          {mentor.bio && (
            <section className="rounded-xl border border-border bg-card p-6">
              <h2 className="section-title mb-3">Professional biography</h2>
              <p className="prose-content whitespace-pre-line">{mentor.bio}</p>
            </section>
          )}

          {mentor.skills.length > 0 && (
            <section className="rounded-xl border border-border bg-card p-6">
              <h2 className="section-title mb-4">Core competencies</h2>
              <div className="flex flex-wrap gap-2">
                {mentor.skills.map((skill) => (
                  <Badge className="badge-info rounded-pill px-3 py-1 text-sm" key={skill} variant="outline">
                    {skill}
                  </Badge>
                ))}
              </div>
            </section>
          )}

          <MentorFeedbackSection
            avgRating={mentor.avg_rating}
            canReview={hasMentorshipHistory}
            initialComment={myFeedback?.comment ?? null}
            initialRating={myFeedback?.rating ?? null}
            mentorId={mentor.user_id}
            ratingCount={mentor.rating_count}
          />

          <MentorReviewsList reviews={reviews} />
        </div>

        <aside className="flex flex-col gap-6 lg:col-span-4">
          <MentorInsightsPanel
            avgRating={mentor.avg_rating}
            avgResponseMinutes={mentor.avg_response_minutes}
            menteeCount={mentor.mentee_count}
            percentileRank={mentor.percentile_rank}
            ratingCount={mentor.rating_count}
          />

          <MentorMetadataCard
            joinedAt={mentor.joined_at}
            lastActiveAt={mentor.last_active_at}
            totalMentorshipHours={mentor.total_mentorship_hours}
          />

          <div className="flex flex-col gap-2">
            <ScheduleSessionButton
              attendeeId={mentor.user_id}
              className="w-full"
              size="default"
              triggerLabel="Book a session"
              variant="default"
            />
            <MessageMentorButton className="w-full" mentorId={mentor.user_id} />
            {assignedTicket && (
              <Link
                className="text-center text-sm text-primary hover:underline"
                href={ROUTES.mentoringTicketChat(assignedTicket.id)}
              >
                Or continue your ticket chat
              </Link>
            )}
          </div>
        </aside>
      </div>

      {hasMentorshipHistory && (
        <ReportMentorDialog mentorId={mentor.user_id} showTrigger={false} ticketId={assignedTicket?.id} />
      )}
      {assignedTicket && <RequestMentorChangeDialog showTrigger={false} ticketId={assignedTicket.id} />}
      {history && <TicketHistoryDialog history={history} />}
    </main>
  );
}
