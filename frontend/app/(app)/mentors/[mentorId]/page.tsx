import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft, Star, Users } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ProfileAvatar } from "@/components/shared/profile-avatar";
import { StatCard } from "@/components/shared/stat-card";
import { MentorRatingForm } from "@/components/mentoring/mentor-rating-form";
import { ReportMentorDialog } from "@/components/mentoring/report-mentor-dialog";
import { RequestMentorChangeDialog } from "@/components/mentoring/request-mentor-change-dialog";
import { MentorProfileActions } from "@/components/mentoring/mentor-profile-actions";
import { TicketHistoryDialog } from "@/components/mentoring/ticket-history-dialog";
import { getMentors, getMyMentorTickets, getTicketHistory } from "@/lib/server/mentoring";
import { getMyFeedback } from "@/lib/server/feedback";
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

  const [mentors, myFeedback, myTickets] = await Promise.all([
    getMentors(),
    getMyFeedback("mentor", mentorId).catch(() => null),
    getMyMentorTickets().catch(() => []),
  ]);

  const mentor = mentors.find((m) => m.user_id === mentorId);
  if (!mentor) notFound();

  // A student can be enrolled in several courses/batches at once, each with
  // its own mentor ticket — this mentor may be assigned on one of several.
  const assignedTicket = myTickets.find(
    (t) => t.status === "assigned" && t.assigned_mentor_id === mentorId,
  );

  const history = assignedTicket ? await getTicketHistory(assignedTicket.id).catch(() => null) : null;

  return (
    <main className="page-container-sm">
      <Link
        className="mb-4 inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
        href={ROUTES.MENTORS}
      >
        <ArrowLeft aria-hidden className="h-4 w-4" />
        All mentors
      </Link>

      <div className="mb-8 flex items-start justify-between gap-4">
        <div className="flex items-center gap-4">
          <ProfileAvatar avatarUrl={mentor.avatar_url} name={mentor.name} size="lg" />
          <div className="flex flex-col gap-1">
            <div className="flex flex-wrap items-center gap-2">
              <h1 className="page-title">{mentor.name}</h1>
              {assignedTicket && <Badge>Your mentor</Badge>}
            </div>
            <p className="text-muted-foreground">{mentor.email}</p>
            {assignedTicket && (
              <Link className="mt-1 w-fit" href={ROUTES.mentoringTicketChat(assignedTicket.id)}>
                <Button size="sm">Chat with your mentor</Button>
              </Link>
            )}
          </div>
        </div>
        <MentorProfileActions ticketId={assignedTicket?.id} />
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

      <MentorRatingForm
        initialComment={myFeedback?.comment ?? null}
        initialRating={myFeedback?.rating ?? null}
        mentorId={mentor.user_id}
      />

      <ReportMentorDialog mentorId={mentor.user_id} showTrigger={false} ticketId={assignedTicket?.id} />
      {assignedTicket && <RequestMentorChangeDialog showTrigger={false} ticketId={assignedTicket.id} />}
      {history && <TicketHistoryDialog history={history} />}
    </main>
  );
}
