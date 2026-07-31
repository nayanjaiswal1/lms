import Link from "next/link";
import { notFound } from "next/navigation";
import { MessageCircle, Star, Users } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { ProfileAvatar } from "@/components/shared/profile-avatar";
import { StatCard } from "@/components/shared/stat-card";
import { MentorRatingForm } from "@/components/mentoring/mentor-rating-form";
import { ReportMentorDialog } from "@/components/mentoring/report-mentor-dialog";
import { RequestMentorChangeDialog } from "@/components/mentoring/request-mentor-change-dialog";
import { MentorProfileActions } from "@/components/mentoring/mentor-profile-actions";
import { TicketHistoryDialog } from "@/components/mentoring/ticket-history-dialog";
import { getMentors, getMyMentorTickets, getTicketHistory } from "@/lib/server/mentoring";
import { getEnrollments } from "@/lib/server/courses";
import { getMyFeedback } from "@/lib/server/feedback";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ mentorId: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { mentorId } = await params;
  return { title: "Mentor", alternates: { canonical: `/mentors/${mentorId}` } };
}

function RatingStars({ rating, count }: { rating: number | null; count: number }) {
  if (rating === null) {
    return (
      <p className="flex items-center gap-1.5 text-sm text-muted-foreground">
        <Star aria-hidden className="h-4 w-4" />
        No ratings yet
      </p>
    );
  }

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

  const [mentors, myFeedback, myTickets, enrollments] = await Promise.all([
    getMentors(),
    getMyFeedback("mentor", mentorId).catch(() => null),
    getMyMentorTickets().catch(() => []),
    getEnrollments().catch(() => []),
  ]);

  const mentor = mentors.find((m) => m.user_id === mentorId);
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
    <main className="page-container-sm">
      <Breadcrumb items={[{ label: "Mentors", href: ROUTES.MENTORS }, { label: mentor.name }]} />

      <div className="card-raised mb-8 flex flex-col gap-6 sm:flex-row sm:items-start sm:justify-between">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-center">
          <ProfileAvatar avatarUrl={mentor.avatar_url} name={mentor.name} size="lg" />
          <div className="flex min-w-0 flex-col gap-1.5">
            <div className="flex flex-wrap items-center gap-2">
              <h1 className="section-title">{mentor.name}</h1>
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
            <RatingStars count={mentor.rating_count} rating={mentor.avg_rating} />
            {assignedTicket && assignedCourse && (
              <p className="text-sm text-muted-foreground">
                Mentoring you in{" "}
                <Link className="text-primary hover:underline" href={ROUTES.course(assignedCourse.slug)}>
                  {assignedCourse.title}
                </Link>
              </p>
            )}
            {assignedTicket && (
              <Link className="mt-1 w-fit" href={ROUTES.mentoringTicketChat(assignedTicket.id)}>
                <Button size="sm">
                  <MessageCircle aria-hidden className="h-4 w-4" />
                  Chat with your mentor
                </Button>
              </Link>
            )}
          </div>
        </div>
        <MentorProfileActions canReport={hasMentorshipHistory} ticketId={assignedTicket?.id} />
      </div>

      <div className="grid-stats mb-8">
        <StatCard icon={Users} label="Mentees" unit="active" value={String(mentor.mentee_count)} />
        <StatCard
          icon={Star}
          label="Rating"
          unit={`${mentor.rating_count} rating${mentor.rating_count === 1 ? "" : "s"}`}
          value={mentor.avg_rating !== null ? mentor.avg_rating.toFixed(1) : "—"}
        />
      </div>

      {mentor.bio && (
        <section className="card-base mb-8 flex flex-col gap-2">
          <h2 className="subsection-title">About</h2>
          <p className="prose-content whitespace-pre-line">{mentor.bio}</p>
        </section>
      )}

      {hasMentorshipHistory && (
        <MentorRatingForm
          initialComment={myFeedback?.comment ?? null}
          initialRating={myFeedback?.rating ?? null}
          mentorId={mentor.user_id}
        />
      )}

      {hasMentorshipHistory && (
        <ReportMentorDialog mentorId={mentor.user_id} showTrigger={false} ticketId={assignedTicket?.id} />
      )}
      {assignedTicket && <RequestMentorChangeDialog showTrigger={false} ticketId={assignedTicket.id} />}
      {history && <TicketHistoryDialog history={history} />}
    </main>
  );
}
