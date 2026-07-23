import Link from "next/link";
import { Star, UserCheck, Users } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ProfileAvatar } from "@/components/shared/profile-avatar";
import { RequestMentorChangeDialog } from "@/components/mentoring/request-mentor-change-dialog";
import { RequestMentorDialog } from "@/components/mentoring/request-mentor-dialog";
import { getMentors, getMyMentorTickets, type MentorDirectoryEntry, type MentorTicket } from "@/lib/server/mentoring";
import { getEnrollments } from "@/lib/server/courses";
import { getMyBatches } from "@/lib/server/batches";
import ROUTES from "@/lib/routes";

export const metadata = { title: "Mentors" };

const TICKET_STATUS_VARIANT: Record<string, "default" | "secondary" | "outline"> = {
  open: "outline",
  assigned: "default",
  closed: "secondary",
};

const TICKET_STATUS_COPY: Record<string, string> = {
  open: "We're finding you a mentor — hang tight.",
  assigned: "You have an assigned mentor.",
};

function MentorTicketCard({
  ticket,
  courseTitle,
  mentor,
}: {
  ticket: MentorTicket;
  courseTitle: string | undefined;
  mentor: MentorDirectoryEntry | undefined;
}) {
  return (
    <div className="card-base flex flex-col gap-3 p-6">
      <div className="flex flex-wrap items-center gap-2">
        <h3 className="font-semibold text-foreground">{courseTitle ?? "Your course"}</h3>
        <Badge variant={TICKET_STATUS_VARIANT[ticket.status] ?? "outline"}>{ticket.status}</Badge>
      </div>
      <p className="text-sm text-foreground">{TICKET_STATUS_COPY[ticket.status]}</p>
      {ticket.status === "assigned" && ticket.assigned_mentor_id && (
        <>
          <div className="flex items-center gap-2.5">
            <ProfileAvatar avatarUrl={mentor?.avatar_url ?? null} name={mentor?.name ?? "Mentor"} size="sm" />
            <p className="text-sm">
              Your mentor: <span className="font-medium text-foreground">{mentor?.name ?? "—"}</span>
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-3">
            <Link href={ROUTES.mentoringTicketChat(ticket.id)}>
              <Button size="sm">Chat with your mentor</Button>
            </Link>
            <Link
              className="text-sm text-primary hover:underline"
              href={ROUTES.mentor(ticket.assigned_mentor_id)}
            >
              View profile &amp; rate
            </Link>
            <RequestMentorChangeDialog ticketId={ticket.id} />
          </div>
        </>
      )}
    </div>
  );
}

function BatchMentorCard({
  batchName,
  mentorId,
  mentor,
}: {
  batchName: string;
  mentorId: string;
  mentor: MentorDirectoryEntry | undefined;
}) {
  return (
    <Link className="card-base card-interactive flex items-center gap-3 p-6" href={ROUTES.mentor(mentorId)}>
      <ProfileAvatar avatarUrl={mentor?.avatar_url ?? null} name={mentor?.name ?? "Mentor"} size="sm" />
      <div className="min-w-0">
        <h3 className="truncate font-semibold text-foreground">{batchName}</h3>
        <p className="truncate text-sm text-muted-foreground">Cohort mentor: {mentor?.name ?? "—"}</p>
      </div>
    </Link>
  );
}

function MentorDirectoryCard({ mentor }: { mentor: MentorDirectoryEntry }) {
  return (
    <Link className="card-base card-interactive flex flex-col gap-4 p-6" href={ROUTES.mentor(mentor.user_id)}>
      <div className="flex items-center gap-3">
        <ProfileAvatar avatarUrl={mentor.avatar_url} name={mentor.name} size="md" />
        <div className="min-w-0">
          <p className="truncate font-semibold text-foreground">{mentor.name}</p>
          <p className="truncate text-sm text-muted-foreground">{mentor.email}</p>
        </div>
      </div>
      <div className="flex items-center gap-4 text-sm text-muted-foreground">
        {mentor.avg_rating !== null ? (
          <span className="flex items-center gap-1">
            <Star aria-hidden className="h-3.5 w-3.5 fill-primary text-primary" />
            <span className="font-semibold text-foreground">{mentor.avg_rating.toFixed(1)}</span>
            <span>({mentor.rating_count})</span>
          </span>
        ) : (
          <span className="flex items-center gap-1">
            <Star aria-hidden className="h-3.5 w-3.5" />
            No ratings yet
          </span>
        )}
        <span className="flex items-center gap-1">
          <Users aria-hidden className="h-3.5 w-3.5" />
          {mentor.mentee_count} mentee{mentor.mentee_count === 1 ? "" : "s"}
        </span>
      </div>
    </Link>
  );
}

function MentorDirectorySection({ mentors }: { mentors: MentorDirectoryEntry[] }) {
  return (
    <section className="flex flex-col gap-4">
      <h2 className="section-title">All mentors</h2>
      {mentors.length === 0 ? (
        <div className="empty-state py-16">
          <UserCheck aria-hidden className="h-12 w-12 text-muted-foreground" />
          <p className="mt-3 text-sm text-muted-foreground">No mentors in your organization yet.</p>
        </div>
      ) : (
        <div className="card-grid">
          {mentors.map((mentor) => (
            <MentorDirectoryCard key={mentor.user_id} mentor={mentor} />
          ))}
        </div>
      )}
    </section>
  );
}

async function YourBatchMentorsSection() {
  const [batches, mentors] = await Promise.all([
    getMyBatches().catch(() => []),
    getMentors().catch(() => []),
  ]);
  const mentored = batches
    .filter((b) => b.mentor_id !== null)
    .map((b) => ({ ...b, mentor_id: b.mentor_id as string }));
  if (mentored.length === 0) return null;

  const mentorFor = (mentorId: string) => mentors.find((m) => m.user_id === mentorId);

  return (
    <section className="flex flex-col gap-4">
      <h2 className="section-title">{mentored.length > 1 ? "Your cohort mentors" : "Your cohort mentor"}</h2>
      <div className="card-grid">
        {mentored.map((b) => (
          <BatchMentorCard batchName={b.name} key={b.id} mentor={mentorFor(b.mentor_id)} mentorId={b.mentor_id} />
        ))}
      </div>
    </section>
  );
}

async function YourMentorsSection() {
  const [tickets, enrollments] = await Promise.all([
    getMyMentorTickets().catch(() => []),
    getEnrollments().catch(() => []),
  ]);
  const active = tickets.filter((t) => t.status === "open" || t.status === "assigned");
  const courseTitle = (courseId: string) => enrollments.find((e) => e.course_id === courseId)?.course.title;

  if (active.length === 0) {
    return (
      <section className="card-base flex flex-wrap items-center justify-between gap-4 p-6">
        <div>
          <h2 className="section-title">No mentor yet</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            {enrollments.length > 0
              ? "Request a mentor for one of your courses and we'll match you with one."
              : "Enroll in a course first, then you can request a mentor for it."}
          </p>
        </div>
        {enrollments.length > 0 ? (
          <RequestMentorDialog
            enrollments={enrollments.map((e) => ({ id: e.course_id, title: e.course.title }))}
          />
        ) : (
          <Link href={ROUTES.COURSES}>
            <Button size="sm">Browse courses</Button>
          </Link>
        )}
      </section>
    );
  }

  const mentors = await getMentors().catch(() => []);
  const mentorFor = (mentorId: string | null) => mentors.find((m) => m.user_id === mentorId);

  return (
    <section className="flex flex-col gap-4">
      <h2 className="section-title">{active.length > 1 ? "Your mentors" : "Your mentor"}</h2>
      <div className="card-grid">
        {active.map((ticket) => (
          <MentorTicketCard
            courseTitle={courseTitle(ticket.course_id)}
            key={ticket.id}
            mentor={mentorFor(ticket.assigned_mentor_id)}
            ticket={ticket}
          />
        ))}
      </div>
    </section>
  );
}

export default async function MentorsDirectoryPage() {
  const mentors = await getMentors().catch(() => []);

  return (
    <main className="page-container py-8">
      <div className="page-header">
        <div className="flex flex-col gap-2">
          <h1 className="page-title">Mentors</h1>
          <p className="text-muted-foreground">
            Your assigned mentor, and everyone else available in your organization.
          </p>
        </div>
      </div>

      <div className="flex flex-col gap-8">
        <YourBatchMentorsSection />
        <YourMentorsSection />
        <MentorDirectorySection mentors={mentors} />
      </div>
    </main>
  );
}
