import Link from "next/link";
import { Inbox, MessageCircle, UserCheck, UserPlus } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ProfileAvatar } from "@/components/shared/profile-avatar";
import { MentorDirectory } from "@/components/mentoring/mentor-directory";
import { RequestMentorChangeDialog } from "@/components/mentoring/request-mentor-change-dialog";
import { RequestMentorDialog } from "@/components/mentoring/request-mentor-dialog";
import { getMentors, type MentorDirectoryEntry } from "@/lib/server/mentoring";
import { getMyTickets, type Ticket } from "@/lib/server/tickets";
import { getEnrollments } from "@/lib/server/courses";
import { getMyBatches } from "@/lib/server/batches";
import { TICKET_KIND } from "@/lib/constants";
import ROUTES from "@/lib/routes";
import { PageHeader } from "@/components/shared/page-header";

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

// Personal mentor rows carry an amber rail so "your people" read apart from
// the directory grid below them at a glance.
const PERSONAL_ROW = "card-base flex flex-col gap-3 p-4 border-l-4 border-l-primary sm:flex-row sm:items-center";

// A mentor only has a chat thread once they're the *assigned* mentor on one
// of the student's tickets — batch/directory listings have no ticket of
// their own, so this is the only way to know whether "Chat" is offered.
function ticketIdByMentor(tickets: Ticket[]): Map<string, string> {
  return new Map(
    tickets
      .filter((t) => t.status === "assigned" && t.assigned_to)
      .map((t) => [t.assigned_to as string, t.id]),
  );
}

function ChatLink({ ticketId, label }: { ticketId: string; label: string }) {
  return (
    <Button asChild className="min-h-11 lg:min-h-9">
      <Link href={ROUTES.mentoringTicketChat(ticketId)}>
        <MessageCircle aria-hidden />
        {label}
      </Link>
    </Button>
  );
}

function MentorTicketCard({
  ticket,
  courseTitle,
  mentor,
}: {
  ticket: Ticket;
  courseTitle: string | undefined;
  mentor: MentorDirectoryEntry | undefined;
}) {
  const assignedTo = ticket.status === "assigned" ? ticket.assigned_to : null;

  return (
    <li className={PERSONAL_ROW}>
      <div className="flex min-w-0 flex-1 items-center gap-3">
        <ProfileAvatar avatarUrl={mentor?.avatar_url ?? null} name={mentor?.name ?? "Mentor"} size="sm" />
        <div className="flex min-w-0 flex-col gap-1">
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="truncate text-base font-semibold text-foreground">
              {assignedTo ? (mentor?.name ?? "Your mentor") : "Matching in progress"}
            </h3>
            <Badge variant={TICKET_STATUS_VARIANT[ticket.status] ?? "outline"}>{ticket.status}</Badge>
          </div>
          <p className="truncate text-sm text-muted-foreground">{courseTitle ?? "Your course"}</p>
          {!assignedTo && <p className="text-sm text-foreground">{TICKET_STATUS_COPY[ticket.status]}</p>}
        </div>
      </div>
      {assignedTo && (
        <div className="flex flex-wrap items-center gap-2">
          <ChatLink label="Chat with your mentor" ticketId={ticket.id} />
          <Button asChild className="min-h-11 lg:min-h-9" variant="outline">
            <Link href={ROUTES.mentor(assignedTo)}>View profile &amp; rate</Link>
          </Button>
          <RequestMentorChangeDialog ticketId={ticket.id} />
        </div>
      )}
    </li>
  );
}

function BatchMentorCard({
  batchName,
  mentorId,
  mentor,
  ticketId,
}: {
  batchName: string;
  mentorId: string;
  mentor: MentorDirectoryEntry | undefined;
  ticketId: string | undefined;
}) {
  return (
    <li className={PERSONAL_ROW}>
      <div className="flex min-w-0 flex-1 items-center gap-3">
        <ProfileAvatar avatarUrl={mentor?.avatar_url ?? null} name={mentor?.name ?? "Mentor"} size="sm" />
        <div className="min-w-0">
          <h3 className="truncate text-base font-semibold text-foreground">{mentor?.name ?? "Cohort mentor"}</h3>
          <p className="truncate text-sm text-muted-foreground">Cohort mentor · {batchName}</p>
        </div>
      </div>
      <div className="flex flex-wrap items-center gap-2">
        {ticketId && <ChatLink label="Chat" ticketId={ticketId} />}
        <Button asChild className="min-h-11 lg:min-h-9" variant="outline">
          <Link href={ROUTES.mentor(mentorId)}>View profile</Link>
        </Button>
      </div>
    </li>
  );
}

async function MentorDirectorySection({ mentors }: { mentors: MentorDirectoryEntry[] }) {
  const tickets = await getMyTickets(TICKET_KIND.MENTORSHIP).catch(() => []);

  return (
    <section aria-labelledby="mentor-directory-title" className="flex flex-col gap-4">
      <h2 className="section-title" id="mentor-directory-title">
        Find a mentor
      </h2>
      {mentors.length === 0 ? (
        <div className="empty-state rounded-xl border border-dashed border-border">
          <UserCheck aria-hidden className="empty-state-icon" />
          <p className="text-sm">No mentors in your organization yet.</p>
        </div>
      ) : (
        <MentorDirectory chatTicketByMentor={Object.fromEntries(ticketIdByMentor(tickets))} mentors={mentors} />
      )}
    </section>
  );
}

async function YourBatchMentorsSection() {
  const [batches, mentors, tickets] = await Promise.all([
    getMyBatches().catch(() => []),
    getMentors().catch(() => []),
    getMyTickets(TICKET_KIND.MENTORSHIP).catch(() => []),
  ]);
  const mentored = batches
    .filter((b) => b.mentor_id !== null)
    .map((b) => ({ ...b, mentor_id: b.mentor_id as string }));
  if (mentored.length === 0) return null;

  const mentorFor = (mentorId: string) => mentors.find((m) => m.user_id === mentorId);
  const ticketByMentor = ticketIdByMentor(tickets);

  return (
    <section className="flex flex-col gap-3">
      <h2 className="subsection-title">{mentored.length > 1 ? "Your cohort mentors" : "Your cohort mentor"}</h2>
      <ul className="flex flex-col gap-3">
        {mentored.map((b) => (
          <BatchMentorCard
            batchName={b.name}
            key={b.id}
            mentor={mentorFor(b.mentor_id)}
            mentorId={b.mentor_id}
            ticketId={ticketByMentor.get(b.mentor_id)}
          />
        ))}
      </ul>
    </section>
  );
}

async function YourMentorsSection() {
  const [tickets, enrollments, mentors] = await Promise.all([
    getMyTickets(TICKET_KIND.MENTORSHIP).catch(() => []),
    getEnrollments().catch(() => []),
    getMentors().catch(() => []),
  ]);
  const active = tickets.filter((t) => t.status === "open" || t.status === "assigned");
  const courseTitle = (courseId: string | null) => enrollments.find((e) => e.course_id === courseId)?.course.title;

  if (active.length === 0) {
    return (
      <section className="card-raised flex flex-col gap-3 p-4 sm:flex-row sm:items-center">
        <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary">
          <UserPlus aria-hidden className="h-5 w-5" />
        </span>
        <div className="min-w-0 flex-1">
          <h2 className="subsection-title">No mentor yet</h2>
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
          <Button asChild className="min-h-11 lg:min-h-9">
            <Link href={ROUTES.COURSES}>Browse courses</Link>
          </Button>
        )}
      </section>
    );
  }

  const mentorFor = (mentorId: string | null) => mentors.find((m) => m.user_id === mentorId);

  return (
    <section className="flex flex-col gap-3">
      <h2 className="subsection-title">{active.length > 1 ? "Your mentors" : "Your mentor"}</h2>
      <ul className="flex flex-col gap-3">
        {active.map((ticket) => (
          <MentorTicketCard
            courseTitle={courseTitle(ticket.course_id)}
            key={ticket.id}
            mentor={mentorFor(ticket.assigned_to)}
            ticket={ticket}
          />
        ))}
      </ul>
    </section>
  );
}

export default async function MentorsDirectoryPage() {
  const mentors = await getMentors().catch(() => []);

  return (
    <main className="page-container">
      <PageHeader title="Mentors" description="Your assigned mentor, and everyone else available in your organization.">
        <Button asChild className="min-h-11 lg:min-h-9" variant="outline">
          <Link href={ROUTES.MENTORING_CONVERSATIONS}>
            <Inbox aria-hidden />
            Your conversations
          </Link>
        </Button>
      </PageHeader>

      <div className="flex flex-col gap-10">
        <div className="flex flex-col gap-6">
          <YourBatchMentorsSection />
          <YourMentorsSection />
        </div>
        <MentorDirectorySection mentors={mentors} />
      </div>
    </main>
  );
}
