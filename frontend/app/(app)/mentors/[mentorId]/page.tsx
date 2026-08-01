import Link from "next/link";
import { notFound } from "next/navigation";
import { Calendar, ShieldCheck, Star, Timer } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { ProfileAvatar } from "@/components/shared/profile-avatar";
import { MentorRatingForm } from "@/components/mentoring/mentor-rating-form";
import { ReportMentorDialog } from "@/components/mentoring/report-mentor-dialog";
import { RequestMentorChangeDialog } from "@/components/mentoring/request-mentor-change-dialog";
import { MentorProfileActions } from "@/components/mentoring/mentor-profile-actions";
import { TicketHistoryDialog } from "@/components/mentoring/ticket-history-dialog";
import { ScheduleSessionButton } from "@/components/mentoring/schedule-session-button";
import { ShareProfileButton } from "@/components/mentoring/share-profile-button";
import { MessageMentorButton } from "@/components/mentoring/message-mentor-button";
import { MentorInsightsPanel } from "@/components/mentoring/mentor-insights-panel";
import { getMentorProfile, getMyMentorTickets, getTicketHistory } from "@/lib/server/mentoring";
import { getEnrollments } from "@/lib/server/courses";
import { getMyFeedback } from "@/lib/server/feedback";
import { formatDate, formatDuration } from "@/lib/mentoring/format";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ mentorId: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { mentorId } = await params;
  return { title: "Mentor", alternates: { canonical: `/mentors/${mentorId}` } };
}

function RatingStars({ rating, count }: { rating: number; count: number }) {
  const rounded = Math.round(rating);
  return (
    <p className="flex items-center gap-1.5 text-sm">
      <span aria-hidden className="flex items-center gap-0.5 text-primary">
        {[1, 2, 3, 4, 5].map((n) => (
          <Star className="h-4 w-4" fill={n <= rounded ? "currentColor" : "none"} key={n} />
        ))}
      </span>
      <span className="font-semibold text-foreground">{rating.toFixed(1)}</span>
      <span className="text-muted-foreground">
        ({count} rating{count === 1 ? "" : "s"})
      </span>
    </p>
  );
}

export default async function MentorProfilePage({ params }: Props) {
  const { mentorId } = await params;

  const [mentor, myFeedback, myTickets, enrollments] = await Promise.all([
    getMentorProfile(mentorId),
    getMyFeedback("mentor", mentorId).catch(() => null),
    getMyMentorTickets().catch(() => []),
    getEnrollments().catch(() => []),
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

  const totalHoursLabel = formatDuration(mentor.total_mentorship_hours);

  return (
    <main className="page-container">
      <Breadcrumb items={[{ label: "Mentors", href: ROUTES.MENTORS }, { label: mentor.name }]} />

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
        <div className="flex flex-col gap-6 lg:col-span-8">
          <div className="card-raised relative flex flex-col gap-4 p-8 sm:flex-row sm:items-center">
            <div className="absolute right-4 top-4 sm:right-6 sm:top-6">
              <MentorProfileActions
                canReport={hasMentorshipHistory}
                mentorId={mentor.user_id}
                ticketId={assignedTicket?.id}
                verified={mentor.verified}
              />
            </div>

            <ProfileAvatar avatarUrl={mentor.avatar_url} name={mentor.name} size="lg" />
            <div className="flex min-w-0 flex-col gap-1.5">
              <div className="flex flex-wrap items-center gap-2 pr-10 sm:pr-0">
                {mentor.verified && (
                  <span className="flex items-center gap-1 text-xs font-semibold uppercase tracking-wide text-primary">
                    <ShieldCheck aria-hidden className="h-3.5 w-3.5" />
                    Verified expert
                  </span>
                )}
              </div>
              <div className="flex flex-wrap items-center gap-2">
                <h1 className="page-title">{mentor.name}</h1>
                {assignedTicket && <Badge>Your mentor</Badge>}
              </div>
              {mentor.current_role && (
                <p className="text-sm font-medium text-foreground">
                  {mentor.current_role}
                  {mentor.years_of_experience !== null &&
                    ` · ${mentor.years_of_experience} yr${mentor.years_of_experience === 1 ? "" : "s"} experience`}
                </p>
              )}
              <p className="truncate text-sm text-muted-foreground">{mentor.email}</p>
              {mentor.avg_rating !== null && <RatingStars count={mentor.rating_count} rating={mentor.avg_rating} />}
              {assignedTicket && assignedCourse && (
                <p className="text-sm text-muted-foreground">
                  Mentoring you in{" "}
                  <Link className="text-primary hover:underline" href={ROUTES.course(assignedCourse.slug)}>
                    {assignedCourse.title}
                  </Link>
                </p>
              )}
              <div className="flex flex-wrap items-center gap-2 pt-2">
                <ScheduleSessionButton
                  attendeeId={mentor.user_id}
                  size="sm"
                  triggerLabel="Book a session"
                  variant="default"
                />
                <ShareProfileButton mentorName={mentor.name} path={ROUTES.mentor(mentor.user_id)} />
              </div>
            </div>
          </div>

          {mentor.bio && (
            <section className="card-base flex flex-col gap-2 p-6">
              <h2 className="subsection-title">Professional biography</h2>
              <p className="prose-content whitespace-pre-line">{mentor.bio}</p>
            </section>
          )}

          {mentor.skills.length > 0 && (
            <section className="card-base flex flex-col gap-3 p-6">
              <h2 className="subsection-title">Core competencies</h2>
              <div className="flex flex-wrap gap-2">
                {mentor.skills.map((skill) => (
                  <Badge key={skill} variant="secondary">
                    {skill}
                  </Badge>
                ))}
              </div>
            </section>
          )}

          {hasMentorshipHistory && (
            <MentorRatingForm
              initialComment={myFeedback?.comment ?? null}
              initialRating={myFeedback?.rating ?? null}
              mentorId={mentor.user_id}
            />
          )}
        </div>

        <aside className="flex flex-col gap-6 lg:col-span-4">
          <MentorInsightsPanel
            avgRating={mentor.avg_rating}
            avgResponseMinutes={mentor.avg_response_minutes}
            menteeCount={mentor.mentee_count}
            percentileRank={mentor.percentile_rank}
            ratingCount={mentor.rating_count}
          />

          <section className="card-base flex flex-col gap-2 p-6 text-sm text-muted-foreground">
            {totalHoursLabel && (
              <p className="flex items-center gap-2">
                <Timer aria-hidden className="h-4 w-4 shrink-0" />
                {totalHoursLabel} of mentorship delivered
              </p>
            )}
            <p className="flex items-center gap-2">
              <Calendar aria-hidden className="h-4 w-4 shrink-0" />
              Joined {formatDate(mentor.joined_at)}
            </p>
          </section>

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
