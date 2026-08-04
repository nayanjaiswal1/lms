import Link from "next/link";
import { MessageCircle } from "lucide-react";
import { ProfileAvatar } from "@/components/shared/profile-avatar";
import { getMyConversations, getMentors } from "@/lib/server/mentoring";
import { getCurrentUser } from "@/lib/server/auth";
import { truncateId, formatDateTime } from "@/lib/mentoring/format";
import ROUTES from "@/lib/routes";

export const metadata = { title: "Conversations" };

export default async function MentorConversationsPage() {
  const [conversations, mentors, currentUser] = await Promise.all([
    getMyConversations(),
    getMentors(),
    getCurrentUser(),
  ]);
  const mentorById = new Map(mentors.map((m) => [m.user_id, m]));

  return (
    <main className="page-container-sm">
      <div className="mb-8 flex flex-col gap-2">
        <h1 className="page-title">Conversations</h1>
        <p className="text-muted-foreground">Direct messages with mentors, independent of any ticket.</p>
      </div>

      {conversations.length === 0 ? (
        <div className="empty-state py-16">
          <MessageCircle aria-hidden className="h-12 w-12 text-muted-foreground" />
          <p className="mt-3 text-sm text-muted-foreground">
            No conversations yet — message a mentor from their profile to start one.
          </p>
        </div>
      ) : (
        <ol aria-label="Conversations" className="flex flex-col gap-3">
          {conversations.map((conv) => {
            const otherPartyId = conv.student_id === currentUser?.id ? conv.mentor_id : conv.student_id;
            const mentor = mentorById.get(otherPartyId);

            return (
              <li key={conv.id}>
                <Link className="card-interactive flex items-center gap-4 p-5" href={ROUTES.mentorConversation(conv.id)}>
                  <ProfileAvatar avatarUrl={mentor?.avatar_url ?? null} name={mentor?.name ?? "User"} size="sm" />
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-medium text-foreground">{mentor?.name ?? truncateId(otherPartyId)}</p>
                    <p className="text-sm text-muted-foreground">
                      Last activity {formatDateTime(conv.updated_at)}
                    </p>
                  </div>
                </Link>
              </li>
            );
          })}
        </ol>
      )}
    </main>
  );
}
