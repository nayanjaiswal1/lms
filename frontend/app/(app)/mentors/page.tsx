import Link from "next/link";
import { Star, UserCheck } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { RequestMentorChangeDialog } from "@/components/mentoring/request-mentor-change-dialog";
import { getMentors, getMyMentorTickets } from "@/lib/server/mentoring";
import ROUTES from "@/lib/routes";

export const metadata = { title: "Mentors — MindForge" };

const TICKET_STATUS_VARIANT: Record<string, "default" | "secondary" | "outline"> = {
  open: "outline",
  assigned: "default",
  closed: "secondary",
};

const TICKET_STATUS_COPY: Record<string, string> = {
  open: "We're finding you a mentor — hang tight.",
  assigned: "You have an assigned mentor.",
};

async function YourMentorCard() {
  const tickets = await getMyMentorTickets().catch(() => []);
  const active = tickets.find((t) => t.status === "open" || t.status === "assigned");
  if (!active) return null;

  const mentors = await getMentors().catch(() => []);
  const mentorName = active.assigned_mentor_id
    ? mentors.find((m) => m.user_id === active.assigned_mentor_id)?.name
    : undefined;

  return (
    <div className="card-base mb-8 flex flex-col gap-3 p-6">
      <div className="flex flex-wrap items-center gap-2">
        <h2 className="section-title">Your mentor</h2>
        <Badge variant={TICKET_STATUS_VARIANT[active.status] ?? "outline"}>{active.status}</Badge>
      </div>
      <p className="text-sm text-foreground">{TICKET_STATUS_COPY[active.status]}</p>
      {active.status === "assigned" && active.assigned_mentor_id && (
        <p className="text-sm">
          Your mentor: <span className="font-medium">{mentorName ?? "—"}</span>
        </p>
      )}
      {active.status === "assigned" && active.assigned_mentor_id && (
        <div className="flex flex-wrap items-center gap-3">
          <Link href={ROUTES.mentoringTicketChat(active.id)}>
            <Button size="sm">Chat with your mentor</Button>
          </Link>
          <Link
            className="text-sm text-primary hover:underline"
            href={ROUTES.mentor(active.assigned_mentor_id)}
          >
            View profile &amp; rate
          </Link>
          <RequestMentorChangeDialog ticketId={active.id} />
        </div>
      )}
    </div>
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
            Browse every mentor in your organization and their track record.
          </p>
        </div>
      </div>

      <YourMentorCard />

      {mentors.length === 0 ? (
        <div className="empty-state py-16">
          <UserCheck aria-hidden className="h-12 w-12 text-muted-foreground" />
          <p className="mt-3 text-sm text-muted-foreground">No mentors in your organization yet.</p>
        </div>
      ) : (
        <div className="table-responsive">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-xs text-muted-foreground">
                <th className="pb-2 font-medium">Name</th>
                <th className="pb-2 font-medium">Email</th>
                <th className="pb-2 font-medium">Mentees</th>
                <th className="pb-2 font-medium">Rating</th>
                <th className="pb-2 font-medium" />
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {mentors.map((mentor) => (
                <tr key={mentor.user_id}>
                  <td className="py-2.5 pr-4 font-medium">{mentor.name}</td>
                  <td className="py-2.5 pr-4 text-muted-foreground">{mentor.email}</td>
                  <td className="py-2.5 pr-4 text-muted-foreground">{mentor.mentee_count}</td>
                  <td className="py-2.5 pr-4">
                    {mentor.avg_rating !== null ? (
                      <span className="flex items-center gap-1">
                        <Star aria-hidden className="h-3.5 w-3.5 fill-primary text-primary" />
                        <span className="font-semibold text-foreground">{mentor.avg_rating.toFixed(1)}</span>
                        <span className="text-muted-foreground">
                          ({mentor.rating_count} rating{mentor.rating_count === 1 ? "" : "s"})
                        </span>
                      </span>
                    ) : (
                      <span className="text-muted-foreground">No ratings yet</span>
                    )}
                  </td>
                  <td className="py-2.5 text-right">
                    <Link
                      className="text-sm text-primary hover:underline"
                      href={ROUTES.mentor(mentor.user_id)}
                    >
                      View profile
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </main>
  );
}
