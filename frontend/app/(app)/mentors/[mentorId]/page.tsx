import { notFound } from "next/navigation";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { MentorHero } from "@/components/mentoring/mentor-hero";
import { ReportMentorDialog } from "@/components/mentoring/report-mentor-dialog";
import { RequestMentorChangeDialog } from "@/components/mentoring/request-mentor-change-dialog";
import { MentorInsightsPanel } from "@/components/mentoring/mentor-insights-panel";
import { MentorMetadataCard } from "@/components/mentoring/mentor-metadata-card";
import { MentorFeedbackSection } from "@/components/mentoring/mentor-feedback-section";
import { MentorReviewsList } from "@/components/mentoring/mentor-reviews-list";
import { BookSessionDialog } from "@/components/sessions/book-session-dialog";
import { AccessGate } from "@/components/shared/access-gate";
import { FEATURES } from "@/lib/features";
import { getMentorProfile } from "@/lib/server/mentoring";
import { getMyTickets } from "@/lib/server/tickets";
import { getEnrollments } from "@/lib/server/courses";
import { getMyFeedback, getPublicFeedback } from "@/lib/server/feedback";
import { getBookingConfig } from "@/lib/server/sessions";
import { TICKET_KIND } from "@/lib/constants";
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

  const [mentor, myFeedback, myTickets, enrollments, reviews, bookingConfig] = await Promise.all([
    getMentorProfile(mentorId),
    getMyFeedback("mentor", mentorId).catch(() => null),
    getMyTickets(TICKET_KIND.MENTORSHIP).catch(() => []),
    getEnrollments().catch(() => []),
    getPublicFeedback("mentor", mentorId, 5).catch(() => []),
    getBookingConfig().catch(() => null),
  ]);

  if (!mentor) notFound();

  // A student can be enrolled in several courses/batches at once, each with
  // its own mentor ticket — this mentor may be assigned on one of several.
  const assignedTicket = myTickets.find(
    (t) => t.status === "assigned" && t.assigned_to === mentorId,
  );
  const assignedCourse = assignedTicket
    ? enrollments.find((e) => e.course_id === assignedTicket.course_id)?.course
    : undefined;

  // Approximates the backend's HasBeenMentoredBy check (which the feedback
  // service already enforces server-side) so we don't show a rating form or
  // "Report this mentor" to someone browsing a mentor they've never had.
  // A ticket's assigned_to is overwritten on reassignment rather than
  // preserved (see mentoring.Repo.HasBeenMentoredBy), so this misses the rare
  // case where a mentor was later swapped out — that edge case has no
  // student-facing endpoint to check today, and Submit() still rejects it
  // server-side if this approximation is ever too permissive.
  const hasMentorshipHistory = myTickets.some((t) => t.assigned_to === mentorId);

  return (
    <main className="page-container">
      <Breadcrumb items={[{ label: "Mentors", href: ROUTES.MENTORS }, { label: mentor.name }]} />

      <div className="flex flex-col gap-6">
        {/* Hero owns every primary action (book, message, ticket chat) so
            they're the first thing on screen at every width. */}
        <MentorHero
          assignedCourse={assignedCourse}
          bookingAction={
            <AccessGate feature={FEATURES.SESSION_BOOKING} mode="hide">
              <BookSessionDialog
                balance={bookingConfig?.balance ?? 0}
                className="min-h-11"
                defaultDurationMinutes={bookingConfig?.config.default_duration_minutes ?? 30}
                mentorId={mentor.user_id}
                mentorName={mentor.name}
                requireCredits={bookingConfig?.config.require_credits ?? false}
                triggerLabel="Book a session"
              />
            </AccessGate>
          }
          canReport={hasMentorshipHistory}
          isYourMentor={Boolean(assignedTicket)}
          mentor={mentor}
          ticketId={assignedTicket?.id}
        />

        {/* Aside comes first in the DOM so stats follow the hero on mobile;
            on lg it's placed into the right column and pinned while scrolling. */}
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
          <aside className="flex flex-col gap-6 lg:sticky lg:top-20 lg:col-span-4 lg:col-start-9 lg:row-start-1 lg:self-start">
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
          </aside>

          <div className="flex min-w-0 flex-col gap-6 lg:col-span-8 lg:col-start-1 lg:row-start-1">
            {mentor.bio && (
              <section className="card-raised">
                <h2 className="subsection-title mb-3">About</h2>
                <p className="prose-content whitespace-pre-line">{mentor.bio}</p>
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
        </div>
      </div>

      {hasMentorshipHistory && (
        <ReportMentorDialog mentorId={mentor.user_id} showTrigger={false} ticketId={assignedTicket?.id} />
      )}
      {assignedTicket && <RequestMentorChangeDialog showTrigger={false} ticketId={assignedTicket.id} />}
    </main>
  );
}
